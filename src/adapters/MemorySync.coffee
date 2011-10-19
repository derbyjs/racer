##  WARNING:
##  ========
##  This file was compiled from a macro.
##  Do not edit it directly.

{lookup, lookupWithVersion, lookupAddPath, lookupSetVersion} = require './lookup'
{clone: specClone} = require '../specHelper'

MemorySync = module.exports = ->
  @_data = world: {}  # maps path -> val
  @_vers = ver: 0  # maps path -> ver
  return

MemorySync:: =
  version: (path, data) ->
    if path then lookupWithVersion(path, data || @_data, @_vers)[1].ver else @_vers.ver

  get: (path, data) ->
    data ||= @_data
    if path then lookup(path, data) else data.world

  getWithVersion: (path, data) ->
    data ||= @_data
    if path
      [obj, currVer] = lookupWithVersion path, data, @_vers
      return [obj, currVer.ver]
    else
      return [data.world, @_vers.ver]

  # Used by RefHelper
  getRef: (path, data) ->
    lookup path, data || @_data, true

  # Used by RefHelper
  getAddPath: (path, data, ver, pathType) ->
    lookupAddPath path, data || @_data, !ver, pathType

  set: (path, value, ver, data) ->
    {1: parent, 2: prop} = lookupSetVersion path, data || @_data, @_vers, ver, 'object'
    return parent[prop] = value

  del: (path, ver, data) ->
    data ||= @_data
    [obj, parent, prop] = lookupSetVersion path, data, @_vers, ver
    if ver
      delete parent[prop]
      return obj
    # If speculatiave, replace the parent object with a clone that
    # has the desired item deleted
    return obj unless parent
    if ~(index = path.lastIndexOf '.')
      parentPath = path.substr 0, index
      [parent, grandparent, parentProp] =
        lookupSetVersion parentPath, data, @_vers, ver
    else
      parent = data.world
      grandparent = data
      parentProp = 'world'
    parentClone = specClone parent
    delete parentClone[prop]
    grandparent[parentProp] = parentClone
    return obj

  
  push: (path, args..., ver, data) ->
    [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    return arr.push args...
  
  unshift: (path, args..., ver, data) ->
    [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    return arr.unshift args...
  
  splice: (path, args..., ver, data) ->
    [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    return arr.splice args...
  
  pop: (path, ver, data) ->
    [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    return arr.pop()
  
  shift: (path, ver, data) ->
    [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    return arr.shift()
  
  insertAfter: (path, afterIndex, value, ver, data) ->
    [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    outOfBounds = !(-1 <= afterIndex <= arr.length - 1)
    throw new Error 'Out of Bounds' if outOfBounds
    arr.splice afterIndex + 1, 0, value
    return arr.length
  
  insertBefore: (path, beforeIndex, value, ver, data) ->
    [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    outOfBounds = !(0 <= beforeIndex <= arr.length)
    throw new Error 'Out of Bounds' if outOfBounds
    arr.splice beforeIndex, 0, value
    return arr.length
  
  remove: (path, startIndex, howMany, ver, data) ->
    [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    outOfBounds = !(0 <= startIndex <= (arr.length && arr.length - 1 || 0))
    throw new Error 'Out of Bounds' if outOfBounds
    return arr.splice startIndex, howMany
  
  move: (path, from, to, ver, data) ->
    [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
    throw new Error 'Not an Array' unless Array.isArray arr
    len = arr.length
    from += len if from < 0
    to += len if to < 0
    outOfBounds = !((0 <= from < len) && (0 <= to < len))
    throw new Error 'Out of Bounds' if outOfBounds
    [value] = arr.splice from, 1  # Remove from old location
    arr.splice to, 0, value  # Insert in new location
    return value

