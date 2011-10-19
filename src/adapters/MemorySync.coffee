##  WARNING:
##  ========
##  This file was compiled from a macro.
##  Do not edit it directly.

{lookup, lookupWithVersion, lookupAddPath, lookupSetVersion} = require './lookup'
{clone: specClone} = require '../specHelper'
{array: arrayMutators} = require '../mutators'

empty = ->

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

  setPre: empty
  setPost: empty
  set: (path, value, ver, data) ->
    data ||= @_data
    @setPre path, ver, data, value
    {1: parent, 2: prop} = lookupSetVersion path, data, @_vers, ver, 'object'
    parent[prop] = value
    @setPost path, ver, data, value
    return value

  delPre: empty
  delPost: empty
  del: (path, ver, data) ->
    data ||= @_data
    @delPre path, ver, data
    [obj, parent, prop] = lookupSetVersion path, data, @_vers, ver
    if ver
      delete parent[prop]
    else
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
    @delPost path, ver, data
    return obj

for method, {numArgs, outOfBounds, fn} of arrayMutators
  do (method, numArgs, outOfBounds, fn) ->
    pre = method + 'Pre'
    post = method + 'Post'
    MemorySync::[pre] = empty
    MemorySync::[post] = empty
    MemorySync::[method] = switch numArgs
      when 0 then (path, ver, data) ->
        data ||= @_data
        @[pre] path, ver, data
        [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
        throw new Error 'Not an Array' unless Array.isArray arr
        throw new Error 'Out of Bounds' if outOfBounds? arr
        out = if fn then fn arr else arr[method]()
        @[post] path, ver, data
        return out
      when 1 then (path, arg0, ver, data) ->
        data ||= @_data
        @[pre] path, ver, data, arg0
        [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
        throw new Error 'Not an Array' unless Array.isArray arr
        throw new Error 'Out of Bounds' if outOfBounds? arr, arg0
        out = if fn then fn arr, arg0 else arr[method] arg0
        @[post] path, ver, data, arg0
        return out
      when 2 then (path, arg0, arg1, ver, data) ->
        data ||= @_data
        @[pre] path, ver, data, arg0, arg1
        [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
        throw new Error 'Not an Array' unless Array.isArray arr
        throw new Error 'Out of Bounds' if outOfBounds? arr, arg0, arg1
        out = if fn then fn arr, arg0, arg1 else arr[method] arg0, arg1
        @[post] path, ver, data, arg0, arg1
        return out
      else (path, args..., ver, data) ->
        data ||= @_data
        @[pre] path, ver, data, args...
        [arr] = lookupSetVersion path, data || @_data, @_vers, ver, 'array'
        throw new Error 'Not an Array' unless Array.isArray arr
        throw new Error 'Out of Bounds' if outOfBounds? arr, args...
        out = if fn then fn arr, args... else arr[method] args...
        @[post] path, ver, data, args...
        return out

