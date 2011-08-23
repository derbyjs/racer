merge = require('../util').merge
specHelper = require '../specHelper'

Memory = module.exports = ->
  @_data = {}
  @ver = 0
  return

Memory:: =
  get: (path, obj = @_data) ->
    if path then @lookup(path, false, obj: obj).obj else obj
  
  set: (path, value, ver, options = {}) ->
    if value && value.$r
      # If we are setting a reference, then copy the transaction
      # , so we do not mutate the transaction stored in Model::_txns.
      # Mutation would otherwise occur via addition of _proto to value
      # during speculative model creation.
      refObjCopy = merge {}, value
      value = refObjCopy
    @ver = ver
    {parent, prop} = out = @lookup path, true, options
    obj = out.obj = parent[prop] = value
    return if options.returnMeta then out else obj
  
  del: (path, ver, options = {}) ->
    @ver = ver
    {parent, prop, obj, path} = out = @lookup path, false, options
    unless parent
      return if options.returnMeta then out else obj
    if options.proto
      # In speculative models, deletion of something in the model data is
      # acheived by making a copy of the parent prototype's properties that
      # does not include the deleted property
      parentProto = Object.getPrototypeOf parent
      if prop of parentProto
        curr = {}
        for key, value of parentProto
          unless key is prop
            curr[key] = if typeof value is 'object'
              Object.create value
            else
              value
        # TODO This line may be the culprit
        # TODO Replace this with cross browser code
        parent.__proto__ = curr
    delete parent[prop]
    return if options.returnMeta then out else obj

  push: (path, values..., ver, options) ->
    if options is undefined
      options = {}
    if options.constructor != Object
      values.push ver
      ver = options
      options = {}
    @ver = ver
    options.array = true
    out = @lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless specHelper.isArray arr
    # TODO Array of references handling
    ret = arr.push values...
    return if options.returnMeta then out else ret

  pop: (path, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless specHelper.isArray arr
    ret = arr.pop()
    return if options.returnMeta then out else ret

  insertAfter: (path, afterIndex, value, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless specHelper.isArray arr
    throw new Error 'Out of Bounds' unless -1 <= afterIndex <= arr.length-1
    ret = arr.splice afterIndex+1, 0, value
    return if options.returnMeta then out else ret

  insertBefore: (path, beforeIndex, value, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless specHelper.isArray arr
    throw new Error 'Out of Bounds' unless 0 <= beforeIndex <= arr.length
    ret = arr.splice beforeIndex, 0, value
    return if options.returnMeta then out else ret

  remove: (path, startIndex, howMany, ver, options = {}) ->
    @ver = ver
    out = @lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless specHelper.isArray arr
    upperBound = if arr.length then arr.length - 1 else 0
    throw new Error 'Out of Bounds' unless 0 <= startIndex <= upperBound
    ret = arr.splice startIndex, howMany
    return if options.returnMeta then out else ret

  splice: (path, startIndex, removeCount, newMembers..., ver, options) ->
    if options is undefined
      options = {}
    if options.constructor != Object
      newMembers.push ver
      ver = options
      options = {}

    @ver = ver
    options.array = true
    out = @lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless specHelper.isArray arr
    ret = arr.splice startIndex, removeCount, newMembers...
    return if options.returnMeta then out else ret

  unshift: (path, newMembers..., ver, options = {}) ->
    if options is undefined
      options = {}
    if options.constructor != Object
      newMembers.push ver
      ver = options
      options = {}

    @ver = ver
    options.array = true
    out = @lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless specHelper.isArray arr
    ret = arr.unshift newMembers...
    return if options.returnMeta then out else ret

  shift: (path, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless specHelper.isArray arr
    ret = arr.shift()
    return if options.returnMeta then out else ret
  
  move: (path, from, to, ver, options = {}) ->
    value = @lookup("#{path}.#{from}", false, options).obj
    to += @lookup(path, false, options).obj.length if to < 0
    if from > to
      @insertBefore path, to, value, ver, options
      from++
    else
      @insertAfter path, to, value, ver, options
    @remove path, from, 1, ver, options

  # TODO Re-write this because the ability to use it in so many ways is too error-prone
  #      Also, this is a ridiculously long function.
  #      returnMeta option is really only used for path retrieval
  # TODO Replace with signature lookup(path, addPath, obj, options)
  lookup: (path, addPath, options) ->
    origPath = path
    {proto, array} = options
    next = options.obj || @_data
    props = path.split '.'
    
    path = ''
    i = 0
    len = props.length

    while i < len
      parent = next
      prop = props[i++]
      
      # In speculative model operations, return a prototype referenced object
      if proto && !specHelper.isSpeculative parent
        parent = specHelper.create parent
      
      pathSegment = prop.dereffedProp || prop
      prop = if prop.arrIndex isnt undefined then prop.arrIndex else prop

      # Store the absolute path we are about to traverse
      path = if path then path + '.' + pathSegment else pathSegment

      # Traverse down the next segment in the path
      next = parent[prop]
      if next is undefined
        unless addPath
          # Return undefined if the object can't be found
          return {obj: next, path, remainingProps: props.slice i}
        # If addPath is true, create empty parent objects implied by path
        if array && i == len
          next = if proto then specHelper.create [] else []
        else
          next = if proto then specHelper.create {} else {}
        parent[prop] = next
      else if proto && typeof next == 'object' && !specHelper.isSpeculative(next)
        # TODO Can we remove this if?
        if specHelper.isSpeculative(parent) && parent.hasOwnProperty prop
          # In case we speculative set to an object before:
          # e.g., model.set 'some.path', key: value
          #   Here, 'some.path' would not have _proto,
          #   but 'some' would have _proto
          # This allows us to add _proto lazily
          next._proto = true
        else
          next = specHelper.create next
        parent[prop] = next
      
      # Check for model references
      if ref = next.$r
        if i == len && options.dontFollowLastRef
          return {path, parent, prop, obj: next}
        {obj: rObj, path: rPath, remainingProps: rRemainingProps} =
          @lookup(ref, addPath, options)
        dereffedPath = rPath + if rRemainingProps?.length then '.' + rRemainingProps.join '.' else ''
        unless key = next.$k
          next = rObj
        else
          keyVal = @lookup(key, false, options).obj
          if specHelper.isArray(keyVal)
            next = keyVal.map (key) =>
              @lookup(dereffedPath + '.' + key, false, options).obj
            # Map array index to key it should be in the dereferenced
            # object
            if props[i]
              props[i] =
                arrIndex: arrIndex = parseInt props[i], 10
                dereffedProp: keyVal[arrIndex]
          else
            dereffedPath = dereffedPath + '.' + @lookup(key, false, options).obj
            # TODO deref the 2nd lookup term above
            next = @lookup(dereffedPath, addPath, options).obj
        path = dereffedPath if i < len
        
        if next is undefined && !addPath && i < len
          # Return undefined if the reference points to nothing and getting
          return {obj: next, path, remainingProps: props.slice i}
    
    return {path, parent, prop, obj: next}
