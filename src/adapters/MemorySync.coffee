{lookup, lookupWithVersion, lookupAddPath, lookupSetVersion} = require './lookup'
{clone: specClone} = require '../specHelper'
{array: arrayMutators} = require '../mutators'

MemorySync = module.exports = ->
  @_data = world: {}  # maps path -> val
  @_vers = ver: 0  # maps path -> ver
  return

MemorySync:: =
  version: (path, data) ->
    if path then lookupWithVersion(path, data || @_data, @_vers)[1].ver else @_vers.ver

  get: (path, data) ->
    if path then lookup(path, data || @_data) else (data && data.world) || @_data.world

  getWithVersion: (path, data) ->
    if path
      [obj, currVer] = lookupWithVersion path, data || @_data, @_vers
      return [obj, currVer.ver]
    else
      return [(data && data.world) || @_data.world, @_vers.ver]

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
    else
      # If speculatiave, replace the parent object with a clone that
      # has the desired item deleted
      return obj unless parent
      if ~(index = path.lastIndexOf '.')
        path = path.substr 0, index
        [parent, grandparent, parentProp] = lookupSetVersion path, data, @_vers, ver
      else
        parent = data.world
        grandparent = data
        parentProp = 'world'
      parentClone = specClone parent
      delete parentClone[prop]
      grandparent[parentProp] = parentClone
      return obj

for method, {outOfBounds, fn} of arrayMutators
  MemorySync::[method] = do (method, outOfBounds, fn) ->
    (path, methodArgs..., ver, data) ->
      [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
      throw new Error 'Not an Array' unless Array.isArray arr
      throw new Error 'Out of Bounds' if outOfBounds? arr, methodArgs
      # TODO Array of references handling
      return if fn then fn arr, methodArgs else arr[method] methodArgs...
