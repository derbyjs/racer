Memory = module.exports = ->
  @_data = {}
  @ver = 0
  return

Memory:: =
  get: (path, obj = @_data) ->
    if path then @_lookup(path, false, obj: obj).obj else obj
  
  set: (path, value, ver, options = {}) ->
    @ver = ver
    out = @_lookup path, true, options
    out.parent[out.prop] = value
    return if options.returnMeta then out else out.obj
  
  del: (path, ver, options = {}) ->
    @ver = ver
    {parent, prop, obj, path} = out = @_lookup path, false, options
    unless parent
      return if options.returnMeta then out else obj
    if options.proto
      # In speculative models, deletion of something in the model data is
      # acheived by making a copy of the parent prototype's properties that
      # does not include the deleted property
      if prop of parent.__proto__
        curr = {}
        for key, value of parent.__proto__
          unless key is prop
            curr[key] = if typeof value is 'object'
              Object.create value
            else
              value
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
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    # TODO Array of references handling
    ret = arr.push values...
    return if options.returnMeta then out else ret

  pop: (path, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    ret = arr.pop()
    return if options.returnMeta then out else ret

  insertAfter: (path, afterIndex, value, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    throw new Error 'Out of Bounds' unless -1 <= afterIndex <= arr.length-1
    ret = arr.splice afterIndex+1, 0, value
    return if options.returnMeta then out else ret

  insertBefore: (path, beforeIndex, value, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    throw new Error 'Out of Bounds' unless 0 <= beforeIndex <= arr.length
    ret = arr.splice beforeIndex, 0, value
    return if options.returnMeta then out else ret

  remove: (path, startIndex, howMany, ver, options = {}) ->
    @ver = ver
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
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
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
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
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    ret = arr.unshift newMembers...
    return if options.returnMeta then out else ret

  shift: (path, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    ret = arr.shift()
    return if options.returnMeta then out else ret
  
  _lookup: (path, addPath, options) ->
    proto = options.proto
    array = options.array
    next = options.obj || @_data
    props = path.split '.'
    
    path = ''
    i = 0
    len = props.length
    while i < len
      parent = next
      prop = props[i++]
      
      # In speculative model operations, return a prototype referenced object
      if proto && !Object::isPrototypeOf(parent)
        parent = Object.create parent
      
      # Traverse down the next segment in the path
      next = parent[prop]
      if next is undefined
        # Return undefined if the object can't be found
        return {obj: next} unless addPath
        # If addPath is true, create empty parent objects implied by path
        next = parent[prop] = if array && i == len then [] else {}
      
      # Store the absolute path traversed so far
      path = if path then path + '.' + prop else prop
      
      # Check for model references
      if ref = next.$r
        key = next.$k
        if key
          keyVal = @_lookup(key, false, options).obj
          if Array.isArray keyVal
            only = next.$o
            next = keyVal.map (key) =>
              mem = @_lookup(ref + '.' + key, false, options).obj
              if Array.isArray only
                scopedMem = {}
                for k, v of mem
                  scopedMem[k] = v if ~only.indexOf k
                mem = scopedMem
              else if only
                mem = mem[only]
              next = mem
          else
            ref = ref + '.' + @_lookup(key, false, options).obj
            next = @_lookup(ref, addPath, options).obj
        else
          next = @_lookup(ref, addPath, options).obj
        path = ref if i < len
        
        # Return undefined if the reference points to nothing and getting
        return {obj: next} if next is undefined && !addPath && i < len
    
    return {path, parent, prop, obj: next}
