transaction = require './transaction'

module.exports = RefHelper = (model) ->
  @_model = model
  @_adapter = model._adapter
  return

RefHelper:: =
  ref: (ref, key, arrOnly) ->
    if arrOnly
      return $r: ref, $k: key, $o: arrOnly
    if key? then $r: ref, $k: key else $r: ref
  
  # If a key is present, merges
  #     TODO key is redundant here
  #     { <path>: { <ref>: { <key>: 1 } } }
  # into
  #     "$keys":
  #       "#{key}":
  #         $:
  #
  # and merges
  #     { <path>: { <ref>: { <key>: 1 } } }
  # into
  #     $refs:
  #       <ref>.<lookup(key)>: 
  #         $:
  #
  # If key is not present, merges
  #     <path>: { <ref>: { $: 1 } }
  # into
  #     $refs:
  #       <ref>: 
  #         $:
  #
  # $refs is a kind of index that allows us to lookup
  # which references pointed to the path, `ref`, or to
  # a path that `ref` is a descendant of.
  #
  # [*] The only purpose of these data structures appears to be for
  # mutator events also emitting to references that pointed at the original
  # mutated path
  #
  # @param {String} path that is de-referenced to a true path represented by
  #                 lookup(ref + '.' + lookup(key))
  # @param {String} ref is what would be the `value` of $r: `value`.
  #                 It's what we are pointing to
  # @param {String} key is a path that points to a pathB or array of paths
  #                 as another lookup chain on the dereferenced `ref`
  # @param {Object} options
  setRefs: (path, ref, key, options) ->
    adapter = @_adapter
    oldRefLookupOptions = dontFollowLastRef: true
    oldRefLookupOptions[k] = v for k, v of options
    oldRefObj = adapter._lookup(path, false, oldRefLookupOptions).obj
    update$refs = (refsKey) ->
      deleteRef = (ref, key) -> # for deleting old refs
        ref += '.' + key if key
        refEntries = adapter._lookup("$refs.#{ref}.$", true, options).obj
        delete refEntries[path]
        pathsExistForRef = false
        for k of refEntries[path]
          pathsExistForRef = true
          break
        unless pathsExistForRef
          adapter.del "$refs.#{ref}", null, options
      if oldRefObj && oldRef = oldRefObj.$r
        oldKey = oldRefObj.$k
        dereffedOldKey = adapter._lookup(oldKey, false, options).obj
        if Array.isArray dereffedOldKey
          dereffedOldKey.forEach (oldKeyMem) ->
            deleteRef oldRef, oldKeyMem
          deleteRef oldRef, null
        else
          deleteRef oldRef, dereffedOldKey
      adapter._lookup("$refs.#{refsKey}.$", true, options).obj[path] = [ref, key]
    if key
      refMap = adapter._lookup("$keys.#{key}.$", true, options).obj[path] = [ref, key]
      keyObj = adapter._lookup(key, false, options).obj
      # keyObj is only valid if it can be a valid path segment
      return if keyObj is undefined
      if Array.isArray keyObj
        refsKeys = keyObj.map (keyVal) -> ref + '.' + keyVal
        return refsKeys.forEach update$refs
      refsKey = ref + '.' + keyObj
    else
      if oldRefObj && oldKey = oldRefObj.$k
        refs = adapter._lookup("$keys.#{oldKey}.$", false, options).obj
        if refs && refs[path]
          delete refs[path]
          refsExistForKey = false
          for k of refs
            refsExistForKey = true
            break
          adapter.del "$keys.#{oldKey}", null, options unless refsExistForKey
      refsKey = ref
    update$refs refsKey

  # If path is a reference's key ($k), then update all entries in the
  # $refs index that use this key. i.e., update the following
  #
  #     $refs: <ref>.<keyVal>: $: <path>: <ref>: <key>: 1
  #                         *
  #                         |
  #                       Update <keyVal> = <lookup(key)>
  updateRefsForKey: (path, options) ->
    self = this
    if refs = @_adapter._lookup("$keys.#{path}.$", false, options).obj
      @_eachValidRef refs, options.obj, (path, ref, key) ->
        self.setRefs path, ref, key, options

  _fastLookup: (path, obj) ->
    for prop in path.split '.'
      return unless obj = obj[prop]
    return obj
  _eachValidRef: (refs, obj = @_adapter._data, callback) ->
    fastLookup = @_fastLookup
    for path, [ref, key] of refs
      # Check to see if the reference is still the same
      o = fastLookup path, obj
      if o && o.$r == ref && o.$k == key
        callback path, ref, key
      else
        delete refs[path]
        # Lazy cleanup

  # Notify any path that referenced the `path`. And
  # notify any path that referenced the path that referenced the path.
  # And notify ... etc...
  notifyPointersTo: (path, method, args, emitPathEvent) ->
    model = @_model
    self = this
    if refs = model.get '$refs'
      _data = model.get()
      # Passes back a set of references when we find references to path.
      # Also passes back a set of references and a path remainder
      # every time we find references to any of path's ancestor paths
      # such that `ancestor_path + path_remainder == path`
      eachRefSetPointingTo = (path, fn) ->
        i = 0
        refPos = refs
        props = path.split '.'
        while prop = props[i++]
          return unless refPos = refPos[prop]
          fn refSet, props.slice(i).join('.') if refSet = refPos.$
      ignoreRoots = []
      emitRefs = (targetPath) ->
        eachRefSetPointingTo targetPath, (refSet, targetPathRemainder) ->
          # refSet has signature: { "#{pointingPath}$#{ref}": [pointingPath, ref], ... }
          self._eachValidRef refSet, _data, (pointingPath, ref, key) ->
            alreadySeen = ignoreRoots.some (root) ->
              root == pointingPath.substr(0, root.length)
            if alreadySeen
              return
            ignoreRoots.push ref
            pointingPath += '.' + targetPathRemainder if targetPathRemainder
            emitPathEvent pointingPath
            emitRefs pointingPath
      emitRefs path
  
  dereferenceTxn: (txn) ->
    switch transaction.method txn
      when 'push'
        path = transaction.path txn
        obj = @_model._specModel(before: 'last')[0]
        if { $r, $k } = @isArrayRef path, obj
          txn[3] = path = $k
          oldPushArgs = transaction.args(txn).slice 1
          newPushArgs = oldPushArgs.map (refObjToAdd) ->
            if refObjToAdd.$r is undefined
              throw new Error 'Trying to push a non-ref onto an array ref'
            if $r != refObjToAdd.$r
              throw new Error "Trying to push elements of type #{refObjToAdd.$r} onto path #{path} that is an array ref of type #{$r}"
            return refObjToAdd.$k
          txn.splice 4, oldPushArgs.length, newPushArgs...
        else
          txn[3] = path = @_model._specModel()[1]
        return txn
      when 'pop'
        path = transaction.path txn
        obj = @_model._specModel(before: 'last')[0]
        if { $r, $k } = @isArrayRef path, obj
          txn[3] = path = $k
        else
          txn[3] = path = @_model._specModel()[1]
        return txn
      else
        # Update the transaction's path with a dereferenced path.
        # It works via _specModel, which automatically dereferences 
        # every transaction path including the just added path.
        txn[3] = path = @_model._specModel()[1]
        return txn

  isArrayRef: (path, data) ->
    options = proto: true, obj: data, dontFollowLastRef: true
    refObj = @_adapter._lookup(path, false, options).obj
    return false if refObj is undefined
    {$r, $k} = refObj
    return false unless $r && $k # this is not a ref
    keyObj = @_adapter._lookup($k, false, options).obj
    return false unless Array.isArray keyObj
    return { $r, $k }
