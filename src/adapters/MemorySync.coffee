merge = require('../util').merge
specHelper = require '../specHelper'
arrMutators = require '../mutators/array'

Memory = module.exports = ->
  @_data = {}
  @ver = 0
  return

Memory:: =
  get: (path, obj = @_data) ->
    if path then @lookup(path, obj).obj else obj
  
  set: (path, value, ver, obj, options = {}) ->
    if value && value.$r
      # If we are setting a reference, then copy the transaction
      # , so we do not mutate the transaction stored in Model::_txns.
      # Mutation would otherwise occur via addition of _proto to value
      # during speculative model creation.
      refObjCopy = merge {}, value
      value = refObjCopy
    @ver = ver
    options.addPath = {}
    {parent, prop} = out = @lookup path, obj, options
    obj = out.obj = parent[prop] = value
    return if options.returnMeta then out else obj
  
  del: (path, ver, obj, options = {}) ->
    @ver = ver
    {proto} = options
    options = Object.create options
    options.addPath = false
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
    {addPath, proto, dontFollowLastRef} = options
    next = obj
    props = path.split '.'
    
    path = ''
    i = 0
    len = props.length

    while i < len
      parent = next
      # In speculative model operations, return a prototype referenced object
      if proto && !specHelper.isSpeculative parent
        parent = specHelper.create parent

      prop = props[i++]
      pathSegment = prop.dereffedProp || prop
      prop = if prop.arrIndex is undefined then prop else prop.arrIndex

      # Store the absolute path we are about to traverse
      path = if path then path + '.' + pathSegment else pathSegment

      # Traverse down the next segment in the path
      next = parent[prop]
      if next is undefined
        unless addPath
          # Return undefined if the object can't be found
          return {obj: next, path, remainingProps: props.slice i}
        # If addPath is true, create empty parent objects implied by path
        setTo = if i == len then addPath else {}
        next = if proto then specHelper.create setTo else setTo
        parent[prop] = next
      else if proto && typeof next == 'object' && !specHelper.isSpeculative(next)
        next = specHelper.create next
        parent[prop] = next
      
      # Check for model references
      if ref = next.$r
        if i == len && dontFollowLastRef
          return {path, parent, prop, obj: next}
        {obj: rObj, path: rPath, remainingProps: rRemainingProps} =
          @lookup ref, obj, options
        dereffedPath = rPath + if rRemainingProps?.length then '.' + rRemainingProps.join '.' else ''
        unless key = next.$k
          next = rObj
        else
          keyVal = @lookup(key, obj).obj
          if specHelper.isArray(keyVal)
            next = keyVal.map (key) =>
              @lookup(dereffedPath + '.' + key, obj).obj
            # Map array index to key it should be in the dereferenced
            # object
            if props[i]
              props[i] =
                arrIndex: arrIndex = parseInt props[i], 10
                dereffedProp: keyVal[arrIndex]
          else
            dereffedPath = dereffedPath + '.' + @lookup(key, obj).obj
            # TODO deref the 2nd lookup term above
            next = @lookup(dereffedPath, obj, options).obj
        path = dereffedPath if i < len
        
        if next is undefined && !addPath && i < len
          # Return undefined if the reference points to nothing and getting
          return {obj: next, path, remainingProps: props.slice i}
    
    return {path, parent, prop, obj: next}

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
