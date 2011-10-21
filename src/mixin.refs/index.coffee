{identifier: specIdentifier} = require '../specHelper'
{hasKeys} = require '../util'

mutators = {}
arrayMutators = {}

module.exports =

  init: ->
    @_refHelper = new RefHelper this

  proto:
    ref: (ref, key) ->
      if key? then $r: ref, $k: key else $r: ref

    arrayRef: (ref, key) ->
      $r: ref, $k: key, $t: 'array'

    _dereference: (path, data) ->
      @_adapter.get path, data ||= @_specModel()
      if data.$remainder then data.$path + '.' + data.$remainder else data.$path

  onMixin: (_mutators) ->
    mutators = _mutators
    for mutator, fn of _mutators
      arrayMutators[mutator] = fn  if fn.type is 'array'

# TODO: Make arrayRefs return the proper values from mutations

RefHelper = (model) ->
  @_model = model
  @_adapter = adapter = model._adapter
  refHelper = this

  model.on 'beforeTxn', (method, args) ->
    return unless (path = args[0])?
    data = model._specModel()

    # Transform args if mutating an array ref
    if arrayMutators[method] && (refObj = adapter.getRef path, data) &&
        refObj.$t is 'array'
      {$r, $k} = refObj
      $k = model._dereference $k, data

      # Handle index args if they are specified by id
      if indexArgs = arrayMutators[method].indexArgs
        ids = {}
        keyObj = adapter.get $k, data
        for i in indexArgs
          continue unless (id = args[i]?.id)?
          # Store the id index in the txn metadata
          ids[i] = id
          # Few operations have multiple indexArgs, so OK to do this in the loop
          args.meta = {ids}
          # Replace id arg with the current index for the given id
          for keyId, index in keyObj
            if `keyId == id`
              args[i] = index
              break

      # TODO Instead of invalidating, roll back the spec model cache by 1 txn
      # model._cache.invalidateSpecModelCache()
      # TODO Add test to make sure that we assign the de-referenced $k to path
      args[0] = path = $k
      if i = mutators[method].insertArgs
        while arg = args[i]
          # TODO: Allow a name other than 'id' for the key id property?
          if id = arg.id
            # Set the object being inserted if it contains any properties
            # other than id
            model.set $r + '.' + id, arg  if hasKeys arg, 'id'
            args[i] = id
          else
            # TODO: Support inserting values without specifying an id?
            throw Error 'arrayRef mutators require an id'
          i++

    else
      # Update the transaction's path with a dereferenced path.
      args[0] = model._dereference path, data
    
  for method of mutators
    do (method) ->
      model.on method, ([path, args...], isLocal, meta) ->
        # Emit events on any references that point to the path or
        # any of its ancestor paths
        refHelper.notifyPointersTo path, method, args, isLocal, meta

  eachNode = (path, value, callback) ->
    callback path, value
    for prop, val of value
      nodePath = "#{path}.#{prop}"
      if Object == val?.constructor
        eachNode nodePath, val, callback
      else
        callback nodePath, val

  model.on 'setPre', ([path, value], ver, data) ->
    eachNode path, value, (path, value) ->
      if value && value.$r
        refHelper.$indexRefs path, value.$r, value.$k, value.$t, ver, data
  
  model.on 'setPost', ([path, value], ver, data) ->
    eachNode path, value, (path, value) ->
      refHelper.updateRefsForKey path, ver, data

  model.on 'delPost', ([path], ver, data) ->
    if refHelper.isPathPointedTo path, data
      refHelper.cleanupPointersTo path, ver, data

  for method of arrayMutators
    model.on method + 'Post', (args, ver, data, meta) ->
      path = args[0]
      data ||= model._specModel()
      if (obj = adapter.get path, data) && obj.$t is 'array'
        # If arrayRef
        indiciesToIds args, meta
      refHelper.updateRefsForKey path, ver, data

  return

# Convert array ref index api back to id api before emitting events
indiciesToIds = (args, meta) ->
  if ids = meta?.ids then for index, id of ids
    args[index] = {id}


# TODO: Rewrite all of this ref indexing code. It's pretty scary right now.

# RefHelper contains code that manages an index of refs: the pointer path,
# ref path, key path, and ref type. It uses this index to
# 1. Manage ref dependencies on an adapter update
# 2. Ultimately raise events at the model layer for refs related to a
#    mutated path.
RefHelper:: =

  isPathPointedTo: (path, data) ->
    found = @_adapter.get "$refs.#{path}.$", data
    return found isnt undefined

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
  $indexRefs: (path, ref, key, type, ver, data) ->
    adapter = @_adapter
    self = @
    oldRefObj = adapter.getRef path, data
    if key
      entry = [ref, key]
      entry.push type if type
      adapter.getAddPath("$keys.#{key}.$", data, ver, 'object')[path] = entry
      keyVal = adapter.get key, data
      # keyVal is only valid if it can be a valid path segment
      return if type is undefined and keyVal is undefined
      if type == 'array'
        keyVal = adapter.getAddPath key, data, ver, 'array'
        refsKeys = keyVal.map (keyValMem) -> ref + '.' + keyValMem
        @_removeOld$refs oldRefObj, path, ver, data
        return refsKeys.forEach (refsKey) ->
          self._update$refs refsKey, path, ref, key, type, ver, data
      refsKey = ref + '.' + keyVal
    else
      if oldRefObj && oldKey = oldRefObj.$k
        refs = adapter.get "$keys.#{oldKey}.$", data
        if refs && refs[path]
          delete refs[path]
          adapter.del "$keys.#{oldKey}", ver, data unless hasKeys refs, specIdentifier
      refsKey = ref
    @_removeOld$refs oldRefObj, path, ver, data
    @_update$refs refsKey, path, ref, key, type, ver, data

  # Private helper function for $indexRefs
  _removeOld$refs: (oldRefObj, path, ver, data) ->
    if oldRefObj && oldRef = oldRefObj.$r
      if oldKey = oldRefObj.$k
        oldKeyVal = @_adapter.get oldKey, data
      if oldKey && (oldRefObj.$t == 'array')
        # If this key was used in an array ref: {$r: path, $k: [...]}
        refHelper = @
        oldKeyVal.forEach (oldKeyMem) ->
          refHelper._removeFrom$refs oldRef, oldKeyMem, path, ver, data
        @_removeFrom$refs oldRef, undefined, path, ver, data
      else
        @_removeFrom$refs oldRef, oldKeyVal, path, ver, data

  # Private helper function for $indexRefs
  _removeFrom$refs: (ref, key, path, ver, data) ->
    refWithKey = ref + '.' + key if key
    refEntries = @_adapter.get "$refs.#{refWithKey}.$", data
    return unless refEntries
    delete refEntries[path]
    unless hasKeys refEntries, specIdentifier
      @_adapter.del "$refs.#{ref}", ver, data
    
  # Private helper function for $indexRefs
  _update$refs: (refsKey, path, ref, key, type, ver, data) ->
    entry = [ref, key]
    entry.push type if type
    # TODO DRY - Above 2 lines are duplicated below
    @_adapter.getAddPath("$refs.#{refsKey}.$", data, ver, 'object')[path] = entry

  # If path is a reference's key ($k), then update all entries in the
  # $refs index that use this key. i.e., update the following
  #
  #     $refs: <ref>.<keyVal>: $: <path>: [<ref>, <key>]
  #                         *
  #                         |
  #                       Update <keyVal> = <lookup(key)>
  updateRefsForKey: (path, ver, data) ->
    self = this
    if refs = @_adapter.get "$keys.#{path}.$", data
      @_eachValidRef refs, data, (path, ref, key, type) ->
        self.$indexRefs path, ref, key, type, ver, data
    @eachValidRefPointingTo path, data, (pointingPath, targetPathRemainder, ref, key, type) ->
      self.updateRefsForKey pointingPath + '.' + targetPathRemainder, ver, data

  ## Iterators ##
  _eachValidRef: (refs, data, callback) ->
    for path, [ref, key, type] of refs

      continue if path == specIdentifier

      # Check to see if the reference is still the same
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
    return unless refs = @_adapter.get '$refs', data
    self = this
    self._eachRefSetPointingTo targetPath, refs, (refSet, targetPathRemainder, possibleIndex) ->
      # refSet has signature: { "#{pointingPath}$#{ref}": [pointingPath, ref], ... }
      self._eachValidRef refSet, data, (pointingPath, ref, key, type) ->
        if type == 'array'
          targetPathRemainder = possibleIndex + '.' + targetPathRemainder
        fn pointingPath, targetPathRemainder, ref, key, type

  eachArrayRefKeyedBy: (path, data, fn) ->
    return unless refs = @_adapter.get '$keys', data
    refSet = (path + '.$').split('.').reduce (refSet, prop) ->
      refSet && refSet[prop]
    , refs
    return unless refSet
    for path, [ref, key, type] of refSet
      fn path, ref, key if type == 'array'

  # Notify any path that referenced the `path`. And
  # notify any path that referenced the path that referenced the path.
  # And notify ... etc...
  notifyPointersTo: (targetPath, method, args, isLocal, meta) ->
    model = @_model
    adapter = @_adapter
    data = model._specModel()
    ignoreRoots = []
    # Takes care of regular refs
    @eachValidRefPointingTo targetPath, data, (pointingPath, targetPathRemainder, ref, key, type) ->
      if type isnt 'array'
        return if alreadySeen pointingPath, ref, ignoreRoots
        pointingPath += '.' + targetPathRemainder if targetPathRemainder
      else if targetPathRemainder
        # Take care of target paths which include an array ref pointer path
        # as a substring of the target path.
        [id, rest...] = targetPathRemainder.split '.'
        keyArr = adapter.get key, data
        index = keyArr.indexOf id
        # Handle numbers just in case
        index = if index == -1 then keyArr.indexOf parseInt(id, 10) else index
        unless index == -1
          pointingPath += '.' + index
          pointingPath += '.' + rest.join('.') if rest.length
      model.emit method, [pointingPath, args...], isLocal

    # Takes care of array refs
    @eachArrayRefKeyedBy targetPath, data, (pointingPath, ref, key) ->
      # Don't mutate the actual arguments
      # args = args.slice()
      # TODO: Pass around args including the path so that the index is correct
      args = [pointingPath, args...]
      # Turn keys into their values
      if i = mutators[method].insertArgs
        obj = adapter.get ref, data
        while (key = args[i])?
          args[i++] = obj[key]
      indiciesToIds args, meta
      model.emit method, args, isLocal

  cleanupPointersTo: (path, ver, data) ->
    adapter = @_adapter
    refs = adapter.get "$refs.#{path}.$", data
    return if refs is undefined
    for pointingPath, [ref, key] of refs
      keyVal = key && adapter.get key, data
      if keyVal && Array.isArray keyVal
        keyMem = path.substr(ref.length + 1, pointingPath.length)
        # Adapter method is used directly to avoid an infinite loop
        adapter.remove key, keyVal.indexOf(keyMem), 1, null, data
        @updateRefsForKey key, ver, data
#      else
#        # TODO Use model.del here instead?
#        adapter.del pointingPath, null

# For avoiding infinite event emission
alreadySeen = (pointingPath, ref, ignoreRoots) ->
  # TODO More proper way to detect cycles? Or is this sufficient?
  seen = ignoreRoots.some (root) ->
    root == pointingPath.substr(0, root.length)
  return true if seen
  ignoreRoots.push ref
  return false
