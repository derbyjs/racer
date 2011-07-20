Memory = module.exports = ->
  @_data = {}
  @ver = 0
  return

Memory:: =
  get: (path, obj = @_data) ->
    if path then @_lookup(path, obj: obj).obj else obj
  
  _refs: (path, options = {}) ->
    refs = @_lookup('$refs', options).obj
    for prop in path.split '.'
      refs = refs[prop] = refs[prop] || {}
    return refs
  
  set: (path, value, ver, options = {}) ->
    @ver = ver
    options.addPath = true
    out = @_lookup path, options
    out.parent[out.prop] = value
    
    # Save a record of any references being set
    if value.$r
      console.log path, value, out.path
      refs = @_refs out.path, options
      if refs.$
        refs.$.push p: path
      else
        refs.$ = [p: path]
    
    return out.path
  
  del: (path, ver, options = {}) ->
    @ver = ver
    out = @_lookup path, options
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
  
  _lookup: (path, options) ->
    {addPath, proto} = options
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
        next = parent[prop] = {}
      
      # Check for model references
      if ref = next.$r
        refObj = @_lookup(ref, options).obj
        if key = next.$k
          keyObj = @_lookup(key, options).obj
          path = ref + '.' + keyObj
          next = @_lookup(path, options).obj
        else
          path = ref
          next = refObj
      else
        # Store the absolute path traversed so far
        path = if path then path + '.' + prop else prop
    
    return obj: next, path: path, parent: parent, prop: prop
