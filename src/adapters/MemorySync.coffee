Memory = module.exports = ->
  @_data = {}
  @ver = 0
  return

Memory:: =
  get: (path, obj = @_data) ->
    if path then @_lookup(path, false, obj: obj).obj else obj
  
  _forRef: (refs, obj = @_data, callback) ->
    fastLookup = (path, obj) ->
      for prop in path.split '.'
        return unless obj = obj[prop]
      return obj
    
    for i, [p, r, k] of refs
      # Check to see if the reference is still the same
      o = fastLookup p, obj
      if o && o.$r == r && o.$k == k
        callback p, r, k
      else
        delete refs[i]
  
  _setRefs: (path, ref, key, options) ->
    if key
      value = [path, ref, key]
      i = value.join '$'
      @_lookup("$keys.#{key}.$", true, options).obj[i] = value
      keyObj = @_lookup(key, false, options).obj
      # keyObj is only valid if it can be a valid path segment
      return if keyObj is undefined
      ref = ref + '.' + keyObj
    else
      value = [path, ref]
      i = value.join '$'
    @_lookup("$refs.#{ref}.$", true, options).obj[i] = value
  
  set: (path, value, ver, options = {}) ->
    @ver = ver
    out = @_lookup path, true, options
    out.parent[out.prop] = value
    
    # Save a record of any references being set
    @_setRefs path, ref, value.$k, options if value && ref = value.$r
    
    # Check to see if setting to a reference's key. If so, update references
    if refs = @_lookup("$keys.#{path}.$", false, options).obj
      self = this
      @_forRef refs, options.obj, (p, r, k) ->
        self._setRefs p, r, k, options
    
    return out.path
  
  del: (path, ver, options = {}) ->
    @ver = ver
    out = @_lookup path, false, options
    {parent, prop} = out
    if options.proto
      # In speculative models, deletion of something in the model data is
      # acheived by making a copy of the parent prototype's properties that
      # does not include the deleted property
      if prop of parent.__proto__
        obj = {}
        for key, value of parent.__proto__
          unless key is prop
            obj[key] = if typeof value is 'object'
              Object.create value
            else
              value
        parent.__proto__ = obj
    delete parent[prop]
    return out.path

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
    arr.push values...
    # TODO Array of references handling
    return out.path

  pop: (path, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    arr.pop()
    return out.path

  insertAfter: (path, afterIndex, value, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    throw new Error 'Out of Bounds' unless -1 <= afterIndex <= arr.length-1
    arr.splice afterIndex+1, 0, value
    return out.path

  insertBefore: (path, beforeIndex, value, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    throw new Error 'Out of Bounds' unless 0 <= beforeIndex <= arr.length
    arr.splice beforeIndex, 0, value
    return out.path

  remove: (path, startIndex, howMany, ver, options = {}) ->
    @ver = ver
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    upperBound = if arr.length then arr.length - 1 else 0
    throw new Error 'Out of Bounds' unless 0 <= startIndex <= upperBound
    arr.splice startIndex, howMany
    return out.path

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
    arr.splice startIndex, removeCount, newMembers...
    return out.path

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
    arr.unshift newMembers...
    return out.path

  shift: (path, ver, options = {}) ->
    @ver = ver
    options.array = true
    out = @_lookup path, true, options
    arr = out.obj
    throw new Error 'Not an Array' unless Array.isArray arr
    arr.shift()
    return out.path
  
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
        if key = next.$k
          ref = ref + '.' + @_lookup(key, false, options).obj
        next = @_lookup(ref, addPath, options).obj
        path = ref if i < len
    
    return obj: next, path: path, parent: parent, prop: prop
