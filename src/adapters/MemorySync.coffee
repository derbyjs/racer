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
    [obj, parent, prop, currVer] =
      lookupSetVersion path, data || @_data, @_vers, ver, 'object'
    if ver && typeof value is 'object'
      @_prefillVersion currVer, value, ver
    return parent[prop] = value

  _prefillVersion: (currVer, obj, ver) ->
    if Array.isArray obj
      for v, i in obj
        @_storeVer currVer, i, v, ver
    else
      for k, v of obj
        @_storeVer currVer, k, v, ver

  _storeVer: (currVer, prop, val, ver) ->
    currVer[prop] = if Array.isArray val then [] else {}
    currVer[prop].ver = ver
    @_prefillVersion currVer[prop], val, ver if typeof val is 'object'

  del: (path, ver, data) ->
    data ||= @_data
    [obj, parent, prop] = lookupSetVersion path, data, @_vers, ver
    if ver
      delete parent[prop]
      return obj
    else
      # If speculatiave
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
