merge = require('../util').merge
specHelper = require '../specHelper'
arrMutators = require '../mutators/array'

Memory = module.exports = ->
  @_data = {}  # maps path -> val
  @_vers = ver: 0  # maps path -> ver
  return

Memory:: =
  version: (path, data = @_data) ->
    if path then @lookup(path, data).currVer.ver else @_vers.ver

  get: (path, data = @_data) ->
    if path
      {obj, currVer} = @lookup path, data
      return {val: obj, ver: currVer.ver}
    else
      return val: data, ver: @_vers.ver
  
  set: (path, value, ver, data = @_data, options = {}) ->
    if value && value.$r
      # If we are setting a reference, then copy the transaction,
      # so we do not mutate the transaction stored in Model::_txns.
      # Mutation would otherwise occur via addition of $spec to value
      # during speculative model creation.
      refObjCopy = merge {}, value
      value = refObjCopy
    options.addPath = {} # set the final node to {} if not found
    options.setVer = ver unless options.proto
    {parent, prop, currVer} = out = @lookup path, data, options
    obj = out.obj = parent[prop] = value
    if !options.proto && typeof value is 'object'
      @_prefillVersion currVer, value, ver
    return if options.returnMeta then out else obj

  _prefillVersion: (currVer, obj, ver) ->
    if Array.isArray obj
      for v, i in obj
        @_storeVer currVer, i, v, ver
    else
      for k, v of obj
        @_storeVer currVer, k, v, ver

  _storeVer: (currVer, prop, val, ver) ->
    currVer[prop] = if Array.isArray val then [] else {}
    currVer[prop].ver = ver
    @_prefillVersion currVer[prop], val, ver if typeof val is 'object'
  
  del: (path, ver, data = @_data, options = {}) ->
    proto = options.proto
    options = Object.create options
    options.addPath = false
    options.setVer = ver unless proto
    {parent, prop, obj} = out = @lookup path, data, options
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

  lookup: (path, data = @_data, options = {}) ->
    {addPath, setVer, proto, dontFollowLastRef} = options
    curr = data
    currVer = @_vers
    props = path.split '.'
    
    origPath = path
    path = ''
    i = 0
    len = props.length

    currVer.ver = setVer if setVer

    while i < len
      parent = curr
      prop = props[i++]
      curr = parent[prop]

      parentVer = currVer
      unless currVer = currVer[prop]
        if setVer && addPath
          currVer = parentVer[prop] = {}
        else
          currVer = parentVer

      # Store the absolute path we are about to traverse
      path = if path then path + '.' + prop else prop

      unless curr?
        unless addPath
          return {currVer, obj: curr, path, remainingProps: props.slice i}
        # If addPath is true, create empty parent objects implied by path
        setTo = if i == len then addPath else {}
        curr = parent[prop] = if proto then specHelper.create setTo else setTo
      else if proto && typeof curr == 'object' && !specHelper.isSpeculative(curr)
        curr = parent[prop] = specHelper.create curr
      
      # Check for model references
      if ref = curr.$r
        if i == len && dontFollowLastRef
          break
        
        {currVer, obj: rObj, path: dereffedPath, remainingProps: rRemainingProps} = @lookup ref, data, options
        currVer.ver = setVer if setVer

        dereffedPath += '.' + rRemainingProps.join '.' if rRemainingProps?.length
        if key = curr.$k
          # keyVer reflects the version set via an array op
          # memVer reflects the version set via an op on a member
          #  or member subpath
          keyVal = @lookup(key, data).obj
          if isArrayRef = Array.isArray(keyVal)
            if i < len
              prop = parseInt props[i++], 10
              prop = keyVal[prop]
              path = dereffedPath + '.' + prop
              {currVer, obj: curr} = curr = @lookup path, data, {setVer}
            else
              curr = keyVal.map (key) => @lookup(dereffedPath + '.' + key, data).obj
          else
            dereffedPath += '.' + keyVal
            # TODO deref the 2nd lookup term above
            curr = @lookup(dereffedPath, data, options).obj
        else
          curr = rObj
        
        path = dereffedPath unless i == len || isArrayRef
        if curr is undefined && !addPath && i < len
          # Return undefined if the reference points to nothing
          return {currVer, obj: curr, path, remainingProps: props.slice i}
      else
        currVer.ver = setVer  if setVer
    
    return {currVer, path, parent, prop, obj: curr}

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
      {path, methodArgs, ver, data, options} = normalizeArgs arguments...
      data ||= @_data
      options.addPath = []
      options.setVer = ver unless options.proto
      out = @lookup path, data, options
      arr = out.obj
      throw new Error 'Not an Array' unless Array.isArray arr
      throw new Error 'Out of Bounds' if outOfBounds? arr, methodArgs
      # TODO Array of references handling
      ret = if fn then fn arr, methodArgs else arr[method] methodArgs...
      return if options.returnMeta then out else ret

Memory::move = (path, from, to, ver, data = @_data, options = {}) ->
  value = @lookup("#{path}.#{from}", data).obj
  to += @lookup(path, data).obj.length if to < 0
  if from > to
    @insertBefore path, to, value, ver, data, options
    from++
  else
    @insertAfter path, to, value, ver, data, options
  @remove path, from, 1, ver, data, options
