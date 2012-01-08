##  WARNING:
##  ========
##  This file was compiled from a macro.
##  Do not edit it directly.

{clone: specClone, create, createObject, createArray} = require '../specHelper'

MemorySync = module.exports = ->
  @_data = world: {}  # maps path -> val
  @version = 0
  return

MemorySync:: =

  setVersion: (ver) ->
    @version = Math.max @version, ver

  get: (path, data) ->
    data ||= @_data
    if path then lookup(path, data) else data.world

  getRef: (path, data) ->
    lookup path, data || @_data, true

  set: (path, value, ver, data) ->
    @setVersion ver
    {1: parent, 2: prop} = lookupSet path, data || @_data, `ver == null`, 'object'
    return parent[prop] = value

  del: (path, ver, data) ->
    @setVersion ver
    data ||= @_data
    speculative = `ver == null`
    [obj, parent, prop] = lookupSet path, data, speculative
    if ver?
      delete parent[prop]
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
    parentClone = specClone parent
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
  
  splice: (path, args..., ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    return arr.splice args...
  
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
  
  insertAfter: (path, afterIndex, value, ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    outOfBounds = !(-1 <= afterIndex <= arr.length - 1)
    throw new Error 'Out of Bounds' if outOfBounds
    arr.splice afterIndex + 1, 0, value
    return arr.length
  
  insertBefore: (path, beforeIndex, value, ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    outOfBounds = !(0 <= beforeIndex <= arr.length)
    throw new Error 'Out of Bounds' if outOfBounds
    arr.splice beforeIndex, 0, value
    return arr.length
  
  remove: (path, startIndex, howMany, ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    outOfBounds = !(0 <= startIndex <= (arr.length && arr.length - 1 || 0))
    throw new Error 'Out of Bounds' if outOfBounds
    return arr.splice startIndex, howMany
  
  move: (path, from, to, ver, data) ->
    @setVersion ver
    [arr] = lookupSet path, data || @_data, `ver == null`, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    len = arr.length
    from += len if from < 0
    to += len if to < 0
    outOfBounds = !((0 <= from < len) && (0 <= to < len))
    throw new Error 'Out of Bounds' if outOfBounds
    [value] = arr.splice from, 1  # Remove from old location
    arr.splice to, 0, value  # Insert in new location
    return value



# Returns value
# Used by getters & reference indexer
# Does not dereference the final item if getRef is truthy
lookup = (path, data, getRef) ->
  curr = data.world
  props = path.split '.'
  path = ''
  data.$remainder = ''
  i = 0
  len = props.length

  while i < len
    prop = props[i++]
    curr = curr[prop]

    # The absolute path traversed so far
    path = if path then path + '.' + prop else prop

    unless curr?
      data.$remainder = props.slice(i).join '.'
      break

    if typeof curr is 'function'
      break if getRef && i == len

      [curr] = refOut = curr lookup, data
      if i == len
        data.$refPath = refOut[1]
      else
        path = refOut[1]

      unless curr?
        # Return if the reference points to nothing
        data.$remainder = props.slice(i).join '.'
        break

  data.$path = path
  return curr

# Returns [value, parent, prop]
# Used by setters & delete
lookupSet = (path, data, speculative, pathType) ->
  curr = data.world = if speculative then create data.world else data.world
  props = path.split '.'
  path = ''
  data.$remainder = ''
  i = 0
  len = props.length

  while i < len
    prop = props[i++]
    parent = curr
    curr = curr[prop]

    # The absolute path traversed so far
    path = if path then path + '.' + prop else prop

    # Create empty objects implied by the path
    if curr?
      curr = parent[prop] = create curr  if speculative && typeof curr is 'object'
    else
      unless pathType
        data.$remainder = props.slice(i).join '.'
        break
      # If pathType is truthy, create empty parent objects implied by path
      curr = parent[prop] = if speculative
          if pathType is 'array' && i == len then createArray() else createObject()
        else
          if pathType is 'array' && i == len then [] else {}

  data.$path = path
  return [curr, parent, prop]
