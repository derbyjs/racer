Memory = module.exports = ->
  @_data = {}
  @ver = 0
  return

Memory:: =
  get: (path, obj = @_data) ->
    value = if path then @_lookup(path, obj: obj).obj else obj
    return value
  
  set: (path, value, ver, options = {}) ->
    @ver = ver
    options.addPath = true
    out = @_lookup path, options
    out.parent[out.prop] = value
    return value
  
  del: (path, ver, options = {}) ->
    @ver = ver
    {parent, prop} = @_lookup path, options
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
  
  _lookup: (path, {obj, addPath, proto, onRef}) ->
    next = obj || @_data
    props = if path and path.split then path.split '.' else []
    
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
        # Return null if the object can't be found
        return {obj: null} unless addPath
        # If addPath is true, create empty parent objects implied by path
        next = parent[prop] = {}
      
      # Check for model references
      if ref = next.$r
        refObj = @get ref, obj
        if key = next.$k
          keyObj = @get key, obj
          path = ref + '.' + keyObj
          next = refObj[keyObj]
        else
          path = ref
          next = refObj
        if onRef
          remainder = [path].concat props.slice(i)
          onRef key, remainder.join('.')
      else
        # Store the absolute path traversed so far
        path = if path then path + '.' + prop else prop
    
    return obj: next, path: path, parent: parent, prop: prop
