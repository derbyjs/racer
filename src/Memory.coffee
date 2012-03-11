##  WARNING:
##  ========
##  This file was compiled from a macro.
##  Do not edit it directly.

{clone, create, createObject, createArray} = require './speculative'

Memory = module.exports = ->
  @flush()
  return

Memory:: =

  flush: ->
    @_data = world: {}
    @version = 0

  init: (obj) ->
    @_data = world: obj.data
    @version = obj.ver

  toJSON: -> data: @_data.world, ver: @version

  setVersion: (ver) ->
    @version = Math.max @version, ver

  get: (path, data, getRef) ->
    data ||= @_data
    # Note that $deref is set to null instead of being deleted; deleting a
    # value in a speculative model would not override the underlying value
    data.$deref = null
    if path then lookup(path, data, getRef) else data.world

  set: (path, value, ver, data) ->
    @setVersion ver
    [obj, parent, prop] = lookupSet path, data || @_data, `ver == null`, 'object'
    parent[prop] = value
    return obj

  del: (path, ver, data) ->
    @setVersion ver
    data ||= @_data
    speculative = `ver == null`
    [obj, parent, prop] = lookupSet path, data, speculative
    if ver?
      delete parent[prop]  if parent
      return obj
    # If speculatiave, replace the parent object with a clone that
    # has the desired item deleted
    return obj unless parent
    if ~(index = path.lastIndexOf '.')
      parentPath = path.substr 0, index
      [parent, grandparent, parentProp] =
        lookupSet parentPath, data, speculative
    else
      parent = data.world
      grandparent = data
      parentProp = 'world'
    parentClone = clone parent
    delete parentClone[prop]
    grandparent[parentProp] = parentClone
    return obj


  push: (path, args..., ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    return arr.push args...

  unshift: (path, args..., ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    return arr.unshift args...

  insert: (path, index, args..., ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    len = arr.length
    arr.splice index, 0, args...
    return arr.length

  pop: (path, ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    return arr.pop()

  shift: (path, ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    return arr.shift()

  remove: (path, index, howMany, ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    len = arr.length
    return arr.splice index, howMany

  move: (path, from, to, howMany, ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    len = arr.length
    from = +from
    to = +to
    from += len if from < 0
    to += len if to < 0
    values = arr.splice from, howMany  # Remove from old location
    arr.splice to, 0, values...  # Insert in new location
    return values


# Returns value
# Used by getters
# Does not dereference the final item if getRef is truthy
lookup = (path, data, getRef) ->
  props = path.split '.'
  len = props.length
  i = 0
  curr = data.world
  path = ''

  while i < len
    prop = props[i++]
    curr = curr[prop]

    # The absolute path traversed so far
    path = if path then path + '.' + prop else prop

    if typeof curr is 'function'
      break if getRef && i == len

      [curr, path, i] = refOut = curr lookup, data, path, props, len, i

    break unless curr?

  return curr

# Returns [value, parent, prop]
# Used by mutators
lookupSet = (path, data, speculative, pathType) ->
  props = path.split '.'
  len = props.length
  i = 0
  curr = data.world = if speculative then create data.world else data.world

  while i < len
    prop = props[i++]
    parent = curr
    curr = curr[prop]

    # Create empty objects implied by the path
    if curr?
      curr = parent[prop] = create curr  if speculative && typeof curr is 'object'
    else
      switch pathType
        when 'object'
          unless i == len
            curr = parent[prop] = if speculative then createObject() else {}
        when 'array'
          if i == len
            curr = parent[prop] = if speculative then createArray() else []
          else
            curr = parent[prop] = if speculative then createObject() else {}
        else
          unless i == len
            parent = curr = undefined
          return [curr, parent, prop]

  return [curr, parent, prop]

