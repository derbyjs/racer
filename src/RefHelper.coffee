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
    update$refs = (refsKey) ->
      refMap = adapter._lookup("$refs.#{refsKey}.$", true, options).obj[path] ||= {}
      keyMap = refMap[ref] ||= {}
      if key
        keyMap[key] = 1
      else
        keyMap['$'] = 1
    if key
      refMap = adapter._lookup("$keys.#{key}.$", true, options).obj[path] ||= {}
      keyMap = refMap[ref] ||= {}
      keyMap[key] = 1
      keyObj = adapter._lookup(key, false, options).obj
      # keyObj is only valid if it can be a valid path segment
      return if keyObj is undefined
      if Array.isArray keyObj
        refsKeys = keyObj.map (keyVal) -> ref + '.' + keyVal
        return refsKeys.forEach update$refs
      refsKey = ref + '.' + keyObj
    else
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
    for path, refMap of refs
      for ref, keyMap of refMap
        for key of keyMap
          key = undefined if key == '$'
          # Check to see if the reference is still the same
          o = fastLookup path, obj
          if o && o.$r == ref && o.$k == key
            callback path, ref, key
          else
            delete keyMap[key]
        if Object.keys(keyMap).length == 0
          delete refMap[ref]
      if Object.keys(refMap).length == 0
        delete refMap[path]

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
