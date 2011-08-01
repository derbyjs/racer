transaction = require './transaction'
{merge, anyKeys} = require './utils'

module.exports = RefHelper = (model) ->
  @_model = model
  @_adapter = model._adapter
  return

ARRAY_OPS = push: 1, unshift: 1, pop: 1, shift: 1, remove: 1, insertAfter: 1, insertBefore: 1, splice: 1

RefHelper:: =
  ref: (ref, key, arrOnly) ->
    if arrOnly
      return $r: ref, $k: key, $o: arrOnly
    if key? then $r: ref, $k: key else $r: ref
  
  # If a key is present, merges
  #     TODO key is redundant here
  #     { <path>: [<ref>, <key>] } # TODO Add a special 'a' flag here to denote array ref?
  # into
  #     "$keys":
  #       "#{key}":
  #         $:
  #
  # and merges
  #     { <path>: [<ref>, <key>] } # TODO Add a special 'a' flag here to denote array ref?
  # into
  #     $refs:
  #       <ref>.<lookup(key)>: 
  #         $:
  #
  # If key is not present, merges
  #     <path>: [<ref>, undefined]
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
  $indexRefs: (path, ref, key, ver, options) ->
    adapter = @_adapter
    options2 = merge {dontFollowLastRef: true}, options
    oldRefObj = adapter._lookup(path, false, options2).obj
    removeFrom$refs = (ref, key) -> # for deleting old refs
      ref += '.' + key if key
      refEntries = adapter._lookup("$refs.#{ref}.$", true, options).obj
      delete refEntries[path]
      unless anyKeys refEntries
        adapter.del "$refs.#{ref}", ver, options
    removeOld$refs = ->
      if oldRefObj && oldRef = oldRefObj.$r
        oldKey = oldRefObj.$k
        oldKeyVal = adapter._lookup(oldKey, false, options).obj
        if Array.isArray oldKeyVal
          # If this key was used in an array ref: {$r: path, $k: [...]}
          oldKeyVal.forEach (oldKeyMem) ->
            removeFrom$refs oldRef, oldKeyMem
          removeFrom$refs oldRef, null
        else
          removeFrom$refs oldRef, oldKeyVal
    update$refs = (refsKey) ->
      adapter._lookup("$refs.#{refsKey}.$", true, options).obj[path] = [ref, key]
    if key
      adapter._lookup("$keys.#{key}.$", true, options).obj[path] = [ref, key]
      keyVal = adapter._lookup(key, false, options).obj
      # keyVal is only valid if it can be a valid path segment
      return if keyVal is undefined
      if Array.isArray keyVal
        refsKeys = keyVal.map (keyValMem) -> ref + '.' + keyValMem
        removeOld$refs()
        return refsKeys.forEach update$refs
      refsKey = ref + '.' + keyVal
    else
      if oldRefObj && oldKey = oldRefObj.$k
        refs = adapter._lookup("$keys.#{oldKey}.$", false, options).obj
        if refs && refs[path]
          delete refs[path]
          adapter.del "$keys.#{oldKey}", ver, options unless anyKeys refs
      refsKey = ref
    removeOld$refs()
    update$refs refsKey

  # If path is a reference's key ($k), then update all entries in the
  # $refs index that use this key. i.e., update the following
  #
  #     $refs: <ref>.<keyVal>: $: <path>: [<ref>, <key>]
  #                         *
  #                         |
  #                       Update <keyVal> = <lookup(key)>
  updateRefsForKey: (path, ver, options) ->
    self = this
    if refs = @_adapter._lookup("$keys.#{path}.$", false, options).obj
      @_eachValidRef refs, options.obj, (path, ref, key) ->
        self.$indexRefs path, ref, key, ver, options

  _fastLookup: (path, obj) ->
    for prop in path.split '.'
      return unless obj = obj[prop]
    return obj

  ## Iterators ##
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

  # Passes back a set of references when we find references to path.
  # Also passes back a set of references and a path remainder
  # every time we find references to any of path's ancestor paths
  # such that `ancestor_path + path_remainder == path`
  _eachRefSetPointingTo: (path, refs, fn) ->
    i = 0
    refPos = refs
    props = path.split '.'
    while prop = props[i++]
      return unless refPos = refPos[prop]
      fn refSet, props.slice(i).join('.') if refSet = refPos.$

  eachValidRefPointingTo: (targetPath, fn) ->
    self = this
    model = @_model
    return unless refs = model.get '$refs'
    _data = model.get()
    self._eachRefSetPointingTo targetPath, refs, (refSet, targetPathRemainder) ->
      # refSet has signature: { "#{pointingPath}$#{ref}": [pointingPath, ref], ... }
      self._eachValidRef refSet, _data, (pointingPath, ref, key) ->
        fn pointingPath, targetPathRemainder, ref, key

  # Notify any path that referenced the `path`. And
  # notify any path that referenced the path that referenced the path.
  # And notify ... etc...
  notifyPointersTo: (targetPath, method, args, emitPathEvent, ignoreRoots = []) ->
    self = this
    self.eachValidRefPointingTo targetPath, (pointingPath, targetPathRemainder, ref, key) ->
      alreadySeen = ignoreRoots.some (root) ->
        # For avoiding infinite event emission
        root == pointingPath.substr(0, root.length)
      return if alreadySeen
      ignoreRoots.push ref
      pointingPath += '.' + targetPathRemainder if targetPathRemainder
      emitPathEvent pointingPath
      self.notifyPointersTo pointingPath, method, args, emitPathEvent, ignoreRoots

  cleanupPointersTo: (path, options) ->
    adapter = @_adapter
    refs = adapter._lookup("$refs.#{path}.$", false, options).obj
    return if refs is undefined
    model = @_model
    for pointingPath, [ref, key] of refs
      keyVal = key && adapter._lookup(key, false, options).obj
      if keyVal && Array.isArray keyVal
        keyMem = path.substr(ref.length + 1, pointingPath.length)
        # TODO Use model.remove here instead?
        adapter.remove key, keyVal.indexOf(keyMem), 1, null, options
#      else
#        # TODO Use model.del here instead?
#        adapter.del pointingPath, null, options
  
  # Used to normalize a transaction to its de-referenced parts before
  # adding it to the model's txnQueue
  dereferenceTxn: (txn) ->
    method = transaction.method txn
    if ARRAY_OPS[method]
      args = transaction.args txn
      sliceFrom = switch method
        when 'push', 'unshift' then 1
        when 'pop', 'shift' then 2
        when 'remove'
          if args.length == 2 then 2 else 3
        when 'insertAfter', 'insertBefore' then 2
        when 'splice' then 3
        else
          throw new Error 'Unimplemented for method ' + method

      path = transaction.path txn
      obj = @_model._specModel()[0]
      if { $r, $k } = @isArrayRef path, obj
        # TODO Instead of invalidating, roll back the spec model cache by 1 txn
        @_model._cache.invalidateSpecModelCache()
        txn[3] = path = $k
        oldPushArgs = transaction.args(txn).slice sliceFrom
        newPushArgs = oldPushArgs.map (refObjToAdd) ->
          if refObjToAdd.$r is undefined
            throw new Error 'Trying to push a non-ref onto an array ref'
          if $r != refObjToAdd.$r
            throw new Error "Trying to push elements of type #{refObjToAdd.$r} onto path #{path} that is an array ref of type #{$r}"
          return refObjToAdd.$k
        txn.splice 3 + sliceFrom, oldPushArgs.length, newPushArgs...
      else
        # Update the transaction's path with a dereferenced path.
        txn[3] = path = @_model._specModel()[1]
      return txn

    # Update the transaction's path with a dereferenced path.
    # It works via _specModel, which automatically dereferences 
    # every transaction path including the just added path.
    txn[3] = path = @_model._specModel()[1]
    return txn

  # isArrayRef
  # @param {String} path that we want to determine is a pointer or not
  # @param {Object} data is the speculative or true model data
  isArrayRef: (path, data) ->
    options = proto: true, obj: data, dontFollowLastRef: true
    refObj = @_adapter._lookup(path, false, options).obj
    return false if refObj is undefined
    {$r, $k} = refObj
    return false unless $r && $k # this is not a ref
    keyObj = @_adapter._lookup($k, false, options).obj
    return false unless Array.isArray keyObj
    return { $r, $k }
