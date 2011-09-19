transaction = require './transaction'
pathParser = require './pathParser'
specHelper = require './specHelper'
{merge, hasKeys} = require './util'
argsNormalizer = require './argsNormalizer'
mutators = require './mutators'
arrayMutators = mutators.array

module.exports = RefHelper = (model) ->
  @_model = model
  @_adapter = model._adapter

  @_setup()
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

  isKeyPath: (path, obj) ->
    throw new Error 'Missing obj' unless obj
    found = @_adapter.lookup("$keys.#{path}.$", obj).obj
    return found isnt undefined

  isPathPointedTo: (path, obj) ->
    throw 'Missing obj' unless obj
    found = @_adapter.lookup("$refs.#{path}.$", obj).obj
    return found isnt undefined

  _setup: ->
    refHelper = @
    adapter = @_adapter

    adapter.__set = adapter.set
    adapter.set = (path, value, ver, obj, options = {}) ->
      obj ||= @_data
      out = null
      # Save a record of any references being set

      maybeIndexRefs = (_path, _value) =>
        if refHelper.isPointer _value
          refHelper.$indexRefs _path, _value.$r, _value.$k, _value.$t, ver, obj, options
        if _path == path
          out = @__set path, value, ver, obj, options

        # TODO Move all instances of updateRefsForKey to an event listener?
        # Check to see if setting to a reference's key. If so, update references
        refHelper.updateRefsForKey _path, ver, obj, options

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
    adapter.del = (path, ver, obj, options = {}) ->
      obj ||= @_data
      out = @__del path, ver, obj, options
      if refHelper.isPathPointedTo path, obj
        refHelper.cleanupPointersTo path, obj, options
      return out

    # Wrap all array mutators at adapter layer to add ref logic
    for method, {normalizeArgs, indexesInArgs} of arrayMutators
      adapter['__' + method] = adapter[method]
      adapter[method] = do (method, normalizeArgs, indexesInArgs) ->
        return ->
          {path, methodArgs, ver, obj, options} = normalizeArgs arguments...
          obj ||= @_data
          #if refHelper.isArrayRef path, obj
          if indexesInArgs
            newIndexes = indexesInArgs(methodArgs).map (index) ->
              return refHelper.arrRefIndex index, path, obj
            indexesInArgs methodArgs, newIndexes

          out = @['__' + method] path, methodArgs..., ver, obj, options
          # Check to see if mutating a reference's key. If so, update references
          refHelper.updateRefsForKey path, ver, obj, options
          return out

  # This function returns the index of an array ref member, given a member
  # id or index (as start) of an array ref (represented by path) in the
  # context of the object, obj.
  arrRefIndex: (start, path, obj) ->
    if 'number' == typeof start
      # index api
      return start

    arr = @_adapter.lookup(path, obj, addPath: []).obj
    if @isArrayRef path, obj
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

  # Used via delegation from Model::ref
  ref: (ref, key) ->
    if key? then $r: ref, $k: key else $r: ref

  # Used via delegation from Model::arrayRef
  arrayRef: (ref, key) ->
    $r: ref, $k: key, $t: 'array'
  
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
  $indexRefs: (path, ref, key, type, ver, obj, options) ->
    adapter = @_adapter
    refHelper = @
    oldRefOptions = merge {dontFollowLastRef: true}, options
    oldRefOptions.addPath = false
    oldRefObj = adapter.lookup(path, obj, oldRefOptions).obj
    if key
      entry = [ref, key]
      entry.push type if type
#      # We denormalize the path here. Why? e.g.,
#      # If path = _group.todoIds, but lookup(path) does not exist at this point,
#      # then the dereferenced path resolves to undefined, which is flawed.
#      path = @denormalizePath path, options.obj
      _options = Object.create options
      _options.addPath = {}
      adapter.lookup("$keys.#{key}.$", obj, _options).obj[path] = entry
      _options = Object.create options
      _options.addPath = false
      keyVal = adapter.lookup(key, obj, _options).obj
      # keyVal is only valid if it can be a valid path segment
      return if type is undefined and keyVal is undefined
      if type == 'array'
        keyOptions = merge {}, options
        keyOptions.addPath = []
        keyVal = adapter.lookup(key, obj, keyOptions).obj
        refsKeys = keyVal.map (keyValMem) -> ref + '.' + keyValMem
        @_removeOld$refs oldRefObj, path, ver, obj, options
        return refsKeys.forEach (refsKey) ->
          refHelper._update$refs refsKey, path, ref, key, type, ver, obj, options
      refsKey = ref + '.' + keyVal
    else
      if oldRefObj && oldKey = oldRefObj.$k
        _options = Object.create options
        _options.addPath = false
        refs = adapter.lookup("$keys.#{oldKey}.$", obj, _options).obj
        if refs && refs[path]
          delete refs[path]
          adapter.del "$keys.#{oldKey}", ver, obj, options unless hasKeys refs, ignore: specHelper.reserved
      refsKey = ref
    @_removeOld$refs oldRefObj, path, ver, obj, options
    @_update$refs refsKey, path, ref, key, type, ver, obj, options

  # Private helper function for $indexRefs
  _removeOld$refs: (oldRefObj, path, ver, obj, options) ->
    if oldRefObj && oldRef = oldRefObj.$r
      if oldKey = oldRefObj.$k
        _options = Object.create options
        _options.addPath = false
        oldKeyVal = @_adapter.lookup(oldKey, obj, _options).obj
      if oldKey && (oldRefObj.$t == 'array')
        # If this key was used in an array ref: {$r: path, $k: [...]}
        refHelper = @
        oldKeyVal.forEach (oldKeyMem) ->
          refHelper._removeFrom$refs oldRef, oldKeyMem, path, ver, obj, options
        @_removeFrom$refs oldRef, undefined, path, ver, obj, options
      else
        @_removeFrom$refs oldRef, oldKeyVal, path, ver, obj, options

  # Private helper function for $indexRefs
  _removeFrom$refs: (ref, key, path, ver, obj, options) ->
    refWithKey = ref + '.' + key if key
    _options = Object.create options
    _options.addPath = false
    refEntries = @_adapter.lookup("$refs.#{refWithKey}.$", obj, _options).obj
    return unless refEntries
    delete refEntries[path]
    unless hasKeys(refEntries, ignore: specHelper.reserved)
      @_adapter.del "$refs.#{ref}", ver, obj, options
    
  # Private helper function for $indexRefs
  _update$refs: (refsKey, path, ref, key, type, ver, obj, options) ->
    entry = [ref, key]
    entry.push type if type
    # TODO DRY - Above 2 lines are duplicated below
    _options = Object.create options
    _options.addPath = {}
    _options.setVer = ver unless _options.proto
    {obj, versCurr} = @_adapter.lookup "$refs.#{refsKey}.$", obj, _options
    _options.dontSplitPath = true
    _options.versCurr = versCurr
    @_adapter.set path, entry, ver, obj, _options

  # If path is a reference's key ($k), then update all entries in the
  # $refs index that use this key. i.e., update the following
  #
  #     $refs: <ref>.<keyVal>: $: <path>: [<ref>, <key>]
  #                         *
  #                         |
  #                       Update <keyVal> = <lookup(key)>
  updateRefsForKey: (path, ver, obj, options) ->
    _options = Object.create options
    _options.addPath = false
    if refs = @_adapter.lookup("$keys.#{path}.$", obj, _options).obj
      @_eachValidRef refs, obj, (path, ref, key, type) =>
        @$indexRefs path, ref, key, type, ver, obj, options
    @eachValidRefPointingTo path, obj, (pointingPath, targetPathRemainder, ref, key, type) =>
      @updateRefsForKey pointingPath + '.' + targetPathRemainder, ver, obj, options

  ## Iterators ##
  _eachValidRef: (refs, obj = @_adapter._data, callback) ->
    fastLookup = pathParser.fastLookup
    for path, [ref, key, type] of refs

      # Ignore the _proto key that we use to identify Object.created objs
      # TODO Better encapsulate this
      continue if path == '_proto'

      # Check to see if the reference is still the same
      o = fastLookup path, obj
      o = @_adapter.lookup(path, obj, dontFollowLastRef: true).obj
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

  eachValidRefPointingTo: (targetPath, obj, fn) ->
    self = this
    adapter = self._adapter
    return unless refs = adapter.lookup('$refs', obj).obj
    self._eachRefSetPointingTo targetPath, refs, (refSet, targetPathRemainder, possibleIndex) ->
      # refSet has signature: { "#{pointingPath}$#{ref}": [pointingPath, ref], ... }
      self._eachValidRef refSet, obj, (pointingPath, ref, key, type) ->
        if type == 'array'
          targetPathRemainder = possibleIndex + '.' + targetPathRemainder
        fn pointingPath, targetPathRemainder, ref, key, type

  eachArrayRefKeyedBy: (path, obj, fn) ->
    return unless refs = @_adapter.lookup("$keys", obj).obj
    refSet = (path + '.$').split('.').reduce (refSet, prop) ->
      refSet && refSet[prop]
    , refs
    return unless refSet
    for path, [ref, key, type] of refSet
      fn path, ref, key if type == 'array'

  # Notify any path that referenced the `path`. And
  # notify any path that referenced the path that referenced the path.
  # And notify ... etc...
  notifyPointersTo: (targetPath, obj, method, args, ignoreRoots = []) ->
    # Takes care of regular refs
    @eachValidRefPointingTo targetPath, obj, (pointingPath, targetPathRemainder, ref, key, type) =>
      unless type == 'array'
        return if @_alreadySeen pointingPath, ref, ignoreRoots
        pointingPath += '.' + targetPathRemainder if targetPathRemainder
      else if targetPathRemainder
        # Take care of target paths which include an array ref pointer path
        # as a substring of the target path.
        [id, rest...] = targetPathRemainder.split '.'
        index = @_toIndex key, id, obj
        unless index == -1
          pointingPath += '.' + index
          pointingPath += '.' + rest.join('.') if rest.length
      @_model.emit method, [pointingPath, args...]

    # Takes care of array refs
    @eachArrayRefKeyedBy targetPath, obj, (pointingPath, ref, key) =>
      # return if @_alreadySeen pointingPath, ref, ignoreRoots
      [firstArgs, arrayMemberArgs] = (mutators.basic[method] || mutators.array[method]).splitArgs args
      if arrayMemberArgs
        ns = @_adapter.lookup(ref, obj).obj
        arrayMemberArgs = arrayMemberArgs.map (arg) ->
          ns[arg] || ns[parseInt arg, 10]
          # { $r: ref, $k: arg }
      args = firstArgs.concat arrayMemberArgs
      @_model.emit method, [pointingPath, args...]

  _toIndex: (arrayRefKey, id, obj) ->
    keyArr = @_adapter.lookup(arrayRefKey, obj).obj
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

  cleanupPointersTo: (path, obj, options) ->
    adapter = @_adapter
    _options = Object.create options
    _options.addPath = false
    refs = adapter.lookup("$refs.#{path}.$", obj, _options).obj
    return if refs is undefined
    model = @_model
    for pointingPath, [ref, key] of refs
      keyVal = key && adapter.lookup(key, obj, _options).obj
      if keyVal && specHelper.isArray keyVal
        keyMem = path.substr(ref.length + 1, pointingPath.length)
        # TODO Use model.remove here instead?
        adapter.remove key, keyVal.indexOf(keyMem), 1, null, obj, options
#      else
#        # TODO Use model.del here instead?
#        adapter.del pointingPath, null, options
  
  # Used to normalize a transaction to its de-referenced parts before
  # adding it to the model's txnQueue
  dereferenceTxn: (txn, obj) ->
    method = transaction.method txn
    args = transaction.args txn
    path = transaction.path txn
    if method of arrayMutators
      if { $r, $k } = @isArrayRef path, obj
        # TODO Instead of invalidating, roll back the spec model cache by 1 txn
        @_model._cache.invalidateSpecModelCache()
        # TODO Add test to make sure that we assign the de-referenced $k to path
        args[0] = path = $k

        if arrayMutators[method].argsToForeignKeys
          args = arrayMutators[method].argsToForeignKeys args, path, $r
      else
        # Update the transaction's path with a dereferenced path if not undefined.
        {obj, path, remainingProps} = @_adapter.lookup path, obj
        if obj is undefined && remainingProps?.length
          args[0] = [path].concat(remainingProps).join('.')
        else
          args[0] = path
      return txn

    # Update the transaction's path with a dereferenced path.
    {obj, path, remainingProps} = @_adapter.lookup path, obj
    if obj is undefined && remainingProps?.length
      args[0] = [path].concat(remainingProps).join('.')
    else
      args[0] = path
    return txn

  # isArrayRef
  # @param {String} path that we want to determine is a pointer or not
  # @param {Object} data is the speculative or true model data
  isArrayRef: (path, data) ->
    refObj = @_adapter.lookup(path, data, dontFollowLastRef: true).obj
    return false if refObj is undefined
    {$r, $k, $t} = refObj
    return false if $t != 'array'
    $k && $k = @dereferencedPath $k, data
    return {$r, $k}
  
  isRefObj: (obj) -> '$r' of obj

  dereferencedPath: (path, data) ->
    meta = @_adapter.lookup path, data, returnMeta: true
    return meta.path

  denormalizePath: (path, data) ->
    {path, obj, remainingProps} = @_adapter.lookup path, data
    return path if obj || ! (remainingProps?.length)
    return [path].concat(remainingProps).join('.')
