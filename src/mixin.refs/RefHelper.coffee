# TODO: Rewrite refs. This file is a mess

transaction = require '../transaction'
pathParser = require '../pathParser'
specHelper = require '../specHelper'
{merge, hasKeys} = require '../util'
mutators = require '../mutators'
arrayMutators = mutators.array

module.exports = RefHelper = (model, doSetup = true) ->
  @_model = model
  @_adapter = model._adapter

  @_setup() if doSetup
  return

# RefHelper contains code that manages an index of refs: the pointer path,
# ref path, key path, and ref type. It uses this index to
# 1. Manage ref dependencies on an adapter update
# 2. Ultimately raise events at the model layer for refs related to a
#    mutated path.
RefHelper:: =

  ## Taxonomy Methods ##

  isPointer: (val) ->
    return !! (val && val.$r)

  isKeyPath: (path, data) ->
    throw new Error 'Missing data' unless data
    found = @_adapter.lookup("$keys.#{path}.$", data, @_adapter._vers).obj
    return found isnt undefined

  isPathPointedTo: (path, data) ->
    throw 'Missing data' unless data
    found = @_adapter.lookup("$refs.#{path}.$", data, @_adapter._vers).obj
    return found isnt undefined

  _setup: ->
    refHelper = @
    adapter = @_adapter

    adapter.__set = adapter.set
    adapter.set = (path, value, ver, data = @_data, options = {}) ->
      out = null
      # Save a record of any references being set

      maybeIndexRefs = (_path, _value) =>
        if refHelper.isPointer _value
          refHelper.$indexRefs _path, _value.$r, _value.$k, _value.$t, ver, data, options
        if _path == path
          out = @__set path, value, ver, data, options

        # TODO Move all instances of updateRefsForKey to an event listener?
        # Check to see if setting to a reference's key. If so, update references
        refHelper.updateRefsForKey _path, ver, data, options

      unless Object == value?.constructor
        maybeIndexRefs path, value
      else
        # TODO Need to traverse an object value, too, for del
        eachNode = (path, value, callback) ->
          callback path, value
          for prop, val of value
            nodePath = "#{path}.#{prop}"
            if Object == val?.constructor
              eachNode nodePath, val, callback
            else
              callback nodePath, val
        eachNode path, value, (nodePath, nodeValue) ->
          maybeIndexRefs nodePath, nodeValue
      return out

    adapter.__del = adapter.del
    adapter.del = (path, ver, data = @_data, options = {}) ->
      out = @__del path, ver, data, options
      if refHelper.isPathPointedTo path, data
        refHelper.cleanupPointersTo path, data, options
      return out

    # Wrap all array mutators at adapter layer to add ref logic
    for method, {normalizeArgs, indexesInArgs} of arrayMutators
      adapter['__' + method] = adapter[method]
      adapter[method] = do (method, normalizeArgs, indexesInArgs) ->
        return ->
          {path, methodArgs, ver, data, options} = normalizeArgs arguments...
          data ||= @_data
          #if refHelper.isArrayRef path, data
          if indexesInArgs
            newIndexes = indexesInArgs(methodArgs).map (index) ->
              return refHelper.arrRefIndex index, path, data
            indexesInArgs methodArgs, newIndexes

          out = @['__' + method] path, methodArgs..., ver, data, options
          # Check to see if mutating a reference's key. If so, update references
          refHelper.updateRefsForKey path, ver, data, options
          return out

  # This function returns the index of an array ref member, given a member
  # id or index (as start) of an array ref (represented by path) in the
  # context of the object, data.
  arrRefIndex: (start, path, data) ->
    if 'number' == typeof start
      # index api
      return start

    arr = @_adapter.lookup(path, data, @_adapter._vers, pathType: 'array').obj
    if @isArrayRef path, data
      # id api
      startIndex = arr.length
      for mem, i in arr
        # TODO parseInt will cause bugs later on when we use string uuids for id
        return startIndex = i if mem.id == start.id || parseInt(mem.id, 10) == parseInt(start.id, 10)

    startIndex = arr.indexOf start.id
    return startIndex if startIndex != -1
    startIndex = arr.indexOf parseInt(start.id, 10)
    return startIndex if startIndex != -1
    return arr.indexOf start.id.toString()

  ## Pointer Builders ##
  
  # If a key is present, merges
  #     TODO key is redundant here
  #     { <path>: [<ref>, <key>, <type>] }
  # into
  #     "$keys":
  #       "#{key}":
  #         $:
  #
  # and merges
  #     { <path>: [<ref>, <key>, <type>] }
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
  # @param {String} type can be undefined or 'array'
  # @param {Number} ver
  # @param {Object} options
  $indexRefs: (path, ref, key, type, ver, data, options) ->
    adapter = @_adapter
    self = @
    oldRefObj = adapter.getRef path, data
    if key
      entry = [ref, key]
      entry.push type if type
#      # We denormalize the path here. Why? e.g.,
#      # If path = _group.todoIds, but lookup(path) does not exist at this point,
#      # then the dereferenced path resolves to undefined, which is flawed.
#      path = @denormalizePath path, options.obj
      _options = Object.create options
      _options.pathType = 'object'
      adapter.lookup("$keys.#{key}.$", data, adapter._vers, _options).obj[path] = entry
      _options = Object.create options
      _options.pathType = false
      keyVal = adapter.lookup(key, data, adapter._vers, _options).obj
      # keyVal is only valid if it can be a valid path segment
      return if type is undefined and keyVal is undefined
      if type == 'array'
        keyOptions = merge {}, options
        keyOptions.pathType = 'array'
        keyVal = adapter.lookup(key, data, adapter._vers, keyOptions).obj
        refsKeys = keyVal.map (keyValMem) -> ref + '.' + keyValMem
        @_removeOld$refs oldRefObj, path, ver, data, options
        return refsKeys.forEach (refsKey) ->
          self._update$refs refsKey, path, ref, key, type, ver, data, options
      refsKey = ref + '.' + keyVal
    else
      if oldRefObj && oldKey = oldRefObj.$k
        _options = Object.create options
        _options.pathType = false
        refs = adapter.lookup("$keys.#{oldKey}.$", data, adapter._vers, _options).obj
        if refs && refs[path]
          delete refs[path]
          adapter.del "$keys.#{oldKey}", ver, data, options unless hasKeys refs, ignore: [specHelper.identifier]
      refsKey = ref
    @_removeOld$refs oldRefObj, path, ver, data, options
    @_update$refs refsKey, path, ref, key, type, ver, data, options

  # Private helper function for $indexRefs
  _removeOld$refs: (oldRefObj, path, ver, data, options) ->
    if oldRefObj && oldRef = oldRefObj.$r
      if oldKey = oldRefObj.$k
        _options = Object.create options
        _options.pathType = false
        oldKeyVal = @_adapter.lookup(oldKey, data, @_adapter._vers, _options).obj
      if oldKey && (oldRefObj.$t == 'array')
        # If this key was used in an array ref: {$r: path, $k: [...]}
        refHelper = @
        oldKeyVal.forEach (oldKeyMem) ->
          refHelper._removeFrom$refs oldRef, oldKeyMem, path, ver, data, options
        @_removeFrom$refs oldRef, undefined, path, ver, data, options
      else
        @_removeFrom$refs oldRef, oldKeyVal, path, ver, data, options

  # Private helper function for $indexRefs
  _removeFrom$refs: (ref, key, path, ver, data, options) ->
    refWithKey = ref + '.' + key if key
    _options = Object.create options
    _options.pathType = false
    refEntries = @_adapter.lookup("$refs.#{refWithKey}.$", data, @_adapter._vers, _options).obj
    return unless refEntries
    delete refEntries[path]
    unless hasKeys(refEntries, ignore: [specHelper.identifier])
      @_adapter.del "$refs.#{ref}", ver, data, options
    
  # Private helper function for $indexRefs
  _update$refs: (refsKey, path, ref, key, type, ver, data, options) ->
    entry = [ref, key]
    entry.push type if type
    # TODO DRY - Above 2 lines are duplicated below
    _options = Object.create options
    _options.pathType = 'object'
    @_adapter.lookup("$refs.#{refsKey}.$", data, @_adapter._vers, _options).obj[path] = entry

  # If path is a reference's key ($k), then update all entries in the
  # $refs index that use this key. i.e., update the following
  #
  #     $refs: <ref>.<keyVal>: $: <path>: [<ref>, <key>]
  #                         *
  #                         |
  #                       Update <keyVal> = <lookup(key)>
  updateRefsForKey: (path, ver, data, options) ->
    _options = Object.create options
    _options.pathType = false
    if refs = @_adapter.lookup("$keys.#{path}.$", data, @_adapter._vers, _options).obj
      @_eachValidRef refs, data, (path, ref, key, type) =>
        @$indexRefs path, ref, key, type, ver, data, options
    @eachValidRefPointingTo path, data, (pointingPath, targetPathRemainder, ref, key, type) =>
      @updateRefsForKey pointingPath + '.' + targetPathRemainder, ver, data, options

  ## Iterators ##
  _eachValidRef: (refs, data = @_adapter._data, callback) ->
    fastLookup = pathParser.fastLookup
    for path, [ref, key, type] of refs

      continue if path == specHelper.identifier

      # Check to see if the reference is still the same
      # o = fastLookup path, obj
      o = @_adapter.getRef path, data
      if o && o.$r == ref && `o.$k == key`
        # test `o.$k == key` not via ===
        # because key is converted to null when JSON.stringified before being sent here via socket.io
        callback path, ref, key, type
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
      if refSet = refPos.$
        fn refSet, props.slice(i).join('.'), prop

  eachValidRefPointingTo: (targetPath, data, fn) ->
    self = this
    adapter = self._adapter
    return unless refs = adapter.lookup('$refs', data, @_adapter._vers).obj
    self._eachRefSetPointingTo targetPath, refs, (refSet, targetPathRemainder, possibleIndex) ->
      # refSet has signature: { "#{pointingPath}$#{ref}": [pointingPath, ref], ... }
      self._eachValidRef refSet, data, (pointingPath, ref, key, type) ->
        if type == 'array'
          targetPathRemainder = possibleIndex + '.' + targetPathRemainder
        fn pointingPath, targetPathRemainder, ref, key, type

  eachArrayRefKeyedBy: (path, data, fn) ->
    return unless refs = @_adapter.lookup("$keys", data, @_adapter._vers).obj
    refSet = (path + '.$').split('.').reduce (refSet, prop) ->
      refSet && refSet[prop]
    , refs
    return unless refSet
    for path, [ref, key, type] of refSet
      fn path, ref, key if type == 'array'

  # Notify any path that referenced the `path`. And
  # notify any path that referenced the path that referenced the path.
  # And notify ... etc...
  notifyPointersTo: (targetPath, data, method, args, isLocal, ignoreRoots = []) ->
    # Takes care of regular refs
    @eachValidRefPointingTo targetPath, data, (pointingPath, targetPathRemainder, ref, key, type) =>
      unless type == 'array'
        return if @_alreadySeen pointingPath, ref, ignoreRoots
        pointingPath += '.' + targetPathRemainder if targetPathRemainder
      else if targetPathRemainder
        # Take care of target paths which include an array ref pointer path
        # as a substring of the target path.
        [id, rest...] = targetPathRemainder.split '.'
        index = @_toIndex key, id, data
        unless index == -1
          pointingPath += '.' + index
          pointingPath += '.' + rest.join('.') if rest.length
      @_model.emit method, [pointingPath, args...], isLocal

    # Takes care of array refs
    @eachArrayRefKeyedBy targetPath, data, (pointingPath, ref, key) =>
      # return if @_alreadySeen pointingPath, ref, ignoreRoots
      [firstArgs, arrayMemberArgs] = (mutators.basic[method] || mutators.array[method]).splitArgs args
      if arrayMemberArgs
        ns = @_adapter.lookup(ref, data, @_adapter._vers).obj
        arrayMemberArgs = arrayMemberArgs.map (arg) ->
          ns[arg] || ns[parseInt arg, 10]
          # { $r: ref, $k: arg }
      args = firstArgs.concat arrayMemberArgs
      @_model.emit method, [pointingPath, args...], isLocal

  _toIndex: (arrayRefKey, id, data) ->
    keyArr = @_adapter.lookup(arrayRefKey, data, @_adapter._vers).obj
    index = keyArr.indexOf id
    if index == -1
      # Handle numbers just in case
      return keyArr.indexOf parseInt(id, 10)
    return index

  # For avoiding infinite event emission
  _alreadySeen: (pointingPath, ref, ignoreRoots) ->
    # TODO More proper way to detect cycles? Or is this sufficient?
    alreadySeen = ignoreRoots.some (root) ->
      root == pointingPath.substr(0, root.length)
    return true if alreadySeen
    ignoreRoots.push ref
    return false

  cleanupPointersTo: (path, data, options) ->
    adapter = @_adapter
    _options = Object.create options
    _options.pathType = false
    refs = adapter.lookup("$refs.#{path}.$", data, @_adapter._vers, _options).obj
    return if refs is undefined
    model = @_model
    for pointingPath, [ref, key] of refs
      keyVal = key && adapter.lookup(key, data, @_adapter._vers, _options).obj
      if keyVal && Array.isArray keyVal
        keyMem = path.substr(ref.length + 1, pointingPath.length)
        # TODO Use model.remove here instead?
        adapter.remove key, keyVal.indexOf(keyMem), 1, null, data, options
#      else
#        # TODO Use model.del here instead?
#        adapter.del pointingPath, null, options
  
  # Used to normalize a transaction to its de-referenced parts before
  # adding it to the model's txnQueue
  dereferenceTxn: (txn, data) ->
    data ||= @_adapter._data
    method = transaction.method txn
    args = transaction.args txn
    path = transaction.path txn
    if method of arrayMutators
      if { $r, $k } = @isArrayRef path, data
        # TODO Instead of invalidating, roll back the spec model cache by 1 txn
        @_model._cache.invalidateSpecModelCache()
        # TODO Add test to make sure that we assign the de-referenced $k to path
        args[0] = path = $k

        if arrayMutators[method].argsToForeignKeys
          args = arrayMutators[method].argsToForeignKeys args, path, $r
      else
        # Update the transaction's path with a dereferenced path if not undefined.
        # TODO: This path assembling should be done in the path getter function
        {obj} = @_adapter.lookup path, data, @_adapter._vers
        args[0] = if obj is undefined && data.$remainder
            data.$path + '.' + data.$remainder
          else data.$path
      return txn

    # Update the transaction's path with a dereferenced path.
    {obj} = @_adapter.lookup path, data, @_adapter._vers
    args[0] = if obj is undefined && data.$remainder
        data.$path + '.' + data.$remainder
      else data.$path
    return txn

  isArrayRef: (path, data) ->
    data ||= @_adapter._data
    refObj = @_adapter.getRef path, data
    return false unless refObj?
    {$r, $k, $t} = refObj
    return false if $t != 'array'
    $k && $k = @dereferencedPath $k, data
    return {$r, $k}
  
  isRef: (obj) -> '$r' of obj

  dereferencedPath: (path, data) ->
    data ||= @_adapter._data
    @_adapter.lookup path, data, @_adapter._vers
    return data.$path

  denormalizePath: (path, data) ->
    {obj} = @_adapter.lookup path, data, @_adapter._vers
    path = data.$path
    if obj is undefined && data.$remainder
        path + '.' + data.$remainder
      else path
