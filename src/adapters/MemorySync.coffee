merge = require('../util').merge
specHelper = require '../specHelper'
arrMutators = require '../mutators/array'

Memory = module.exports = ->
  @_data = {}
  @ver = 0    # root node starts at ver 0
  @_vers = {}
  return

Memory:: =
  version: (path, obj = @_data) ->
    if path
      val = @lookup(path, obj).ver
      return val
    return @ver

  get: (path, obj = @_data) ->
    if path
      {obj, ver} = @lookup path, obj
      return {val: obj, ver}
    else
      return val: obj, ver: @ver
  
  set: (path, value, ver, obj, options = {}) ->
    if value && value.$r
      # If we are setting a reference, then copy the transaction
      # , so we do not mutate the transaction stored in Model::_txns.
      # Mutation would otherwise occur via addition of _proto to value
      # during speculative model creation.
      refObjCopy = merge {}, value
      value = refObjCopy
    @ver = ver
    options.addPath = {} # set the final node to {} if not found
    options.setVer = ver unless options.proto
    {parent, prop, versCurr} = out = @lookup path, obj, options
    obj = out.obj = parent[prop] = value
    if !options.proto && 'object' == typeof value
      @_prefillVersion versCurr, value, ver
    return if options.returnMeta then out else obj

  _prefillVersion: (versCurr, obj, ver) ->
    if Array.isArray obj
      for v, i in obj
        @_storeVer versCurr, i, v, ver
    else if Object == obj.constructor
      for k, v of obj
        @_storeVer versCurr, k, v, ver

  _storeVer: (versCurr, prop, val, ver) ->
    versCurr[prop] = if Array.isArray val then [] else {}
    versCurr[prop].ver = ver
    @_prefillVersion versCurr[prop], val, ver if 'object' == typeof val
  
  del: (path, ver, obj, options = {}) ->
    if ver < @ver
      throw new Error 'Cannot set to a ver that is less than adapter ver'
    @ver = ver
    proto = options.proto
    options = Object.create options
    options.addPath = false
    options.setVer = ver unless proto
    {parent, prop, obj, path} = out = @lookup path, obj, options
    unless parent
      return if options.returnMeta then out else obj
    if proto
      # In speculative models, deletion of something in the model data is
      # acheived by making a copy of the parent prototype's properties that
      # does not include the deleted property
      parentProto = Object.getPrototypeOf parent
      if prop of parentProto
        curr = {}
        for key, value of parentProto
          unless key is prop
            curr[key] = if typeof value is 'object'
              specHelper.create value
            else
              value
        # TODO Replace this with cross browser code
        parent.__proto__ = curr
    delete parent[prop]
    return if options.returnMeta then out else obj

  lookup: (path, obj = @_data, options = {}) ->
    {addPath, setVer, proto, dontFollowLastRef} = options
    curr = obj
    versCurr = @_vers
    props = path.split '.'
    
    origPath = path
    path = ''
    i = 0
    len = props.length

    # spec the root node if in proto mode
    if proto && !specHelper.isSpeculative curr
      curr = specHelper.create curr

    @ver = setVer if setVer
    ver = @ver # Track ver for getters

    while i < len
      parent = curr
      prop = props[i++]
      if prop == ''
        throw new Error "You have a mistake in your path #{origPath}"
      curr = parent[prop]

      versParent = versCurr
      versCurr = versParent[prop]

      # Store the absolute path we are about to traverse
      path = if path then path + '.' + prop else prop

      if curr is undefined
        unless addPath
          return {ver, versCurr, obj: curr, path, remainingProps: props.slice i}
        # If addPath is true, create empty parent objects implied by path
        setTo = if i == len then addPath else {}
        curr = parent[prop] = if proto then specHelper.create setTo else setTo
      else if proto && typeof curr == 'object' && !specHelper.isSpeculative(curr)
        curr = parent[prop] = specHelper.create curr

      if setVer && versCurr is undefined && addPath
        setTo = if i == len then addPath else {}
        versCurr = versParent[prop] = if setTo.constructor == Object then {} else []

      # Check for model references
      unless ref = curr.$r
        if setVer
          versCurr.ver = setVer
        ver = versCurr.ver if versCurr?.ver
      else
        if i == len && dontFollowLastRef
          ver = versCurr.ver if versCurr.ver
          return {ver, versCurr, path, parent, prop, obj: curr}

        {ver, versCurr, obj: rObj, path: dereffedPath, remainingProps: rRemainingProps} = @lookup ref, obj, options
        dereffedPath += '.' + rRemainingProps.join '.' if rRemainingProps?.length
        unless key = curr.$k
          curr = rObj
          if typeof curr == 'object'
            versCurr.ver = setVer if setVer
            ver = versCurr.ver
        else
          # keyVer reflects the version set via an array op
          # memVer reflects the version set via an op on a member
          #  or member subpath
          keyVal = @lookup(key, obj).obj
          if isArrayRef = specHelper.isArray(keyVal)
            if i < len
              prop = parseInt props[i++], 10
              prop = keyVal[prop]
              path = dereffedPath + '.' + prop
              {versCurr, obj: curr} = curr = @lookup path, obj, {setVer}
            else
              curr = keyVal.map (key) => @lookup(dereffedPath + '.' + key, obj).obj
          else
            dereffedPath += '.' + keyVal
            # TODO deref the 2nd lookup term above
            curr = @lookup(dereffedPath, obj, options).obj
        path = dereffedPath unless i == len || isArrayRef
        if curr is undefined && !addPath && i < len
          # Return undefined if the reference points to nothing
          return {ver, versCurr, obj: curr, path, remainingProps: props.slice i}
    return {ver, versCurr, path, parent, prop, obj: curr}

xtraArrMutConf =
  insertAfter:
    outOfBounds: (arr, [afterIndex, _]) ->
      return ! (-1 <= afterIndex <= arr.length-1)
    fn: (arr, [afterIndex, value]) ->
      return arr.splice afterIndex+1, 0, value
  insertBefore:
    outOfBounds: (arr, [beforeIndex,_]) ->
      return ! (0 <= beforeIndex <= arr.length)
    fn: (arr, [beforeIndex, value]) ->
      return arr.splice beforeIndex, 0, value
  remove:
    outOfBounds: (arr, [startIndex, _]) ->
      upperBound = if arr.length then arr.length-1 else 0
      return ! (0 <= startIndex <= upperBound)
    fn: (arr, [startIndex, howMany]) ->
      return arr.splice startIndex, howMany

for method, {compound, normalizeArgs} of arrMutators
  continue if compound
  Memory::[method] = do (method, normalizeArgs) ->
    if xtraConf = xtraArrMutConf[method]
      outOfBounds = xtraConf.outOfBounds
      fn = xtraConf.fn
    return ->
      {path, methodArgs, ver, obj, options} = normalizeArgs arguments...
      @ver = ver
      options.addPath = []
      options.setVer = ver unless options.proto
      out = @lookup path, obj, options
      arr = out.obj
      throw new Error 'Not an Array' unless specHelper.isArray arr
      throw new Error 'Out of Bounds' if outOfBounds? arr, methodArgs
      # TODO Array of references handling
      ret = if fn then fn arr, methodArgs else arr[method] methodArgs...
      return if options.returnMeta then out else ret

Memory::move = (path, from, to, ver, obj, options = {}) ->
  value = @lookup("#{path}.#{from}", obj).obj
  to += @lookup(path, obj).obj.length if to < 0
  if from > to
    @insertBefore path, to, value, ver, obj, options
    from++
  else
    @insertAfter path, to, value, ver, obj, options
  @remove path, from, 1, ver, obj, options
