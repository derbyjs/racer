merge = require('../util').merge
{create, createObject, createArray, isSpeculative} = require '../specHelper'
arrMutators = require '../mutators/array'

Memory = module.exports = ->
  @_data = {}  # maps path -> val
  @_vers = ver: 0  # maps path -> ver
  return

Memory:: =
  version: (path, data) ->
    if path then lookup(path, data || @_data, @_vers).currVer.ver else @_vers.ver

  get: (path, data) ->
    if path
      {obj, currVer} = lookup path, data || @_data, @_vers
      return {val: obj, ver: currVer.ver}
    else
      return val: data || @_data, ver: @_vers.ver
  
  set: (path, value, ver, data, options = {}) ->
    options.pathType = 'object'
    options.setVer = ver unless options.speculative
    {parent, prop, currVer} = lookup path, data || @_data, @_vers, options
    if !options.speculative && typeof value is 'object'
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
  
  del: (path, ver, data, options = {}) ->
    speculative = options.speculative
    options = Object.create options
    options.pathType = false
    options.setVer = ver unless speculative
    {parent, prop, obj} = lookup path, data || @_data, @_vers, options
    unless parent
      return obj
    if speculative
      # In speculative models, deletion of something in the model data is
      # acheived by making a copy of the parent prototype's properties that
      # does not include the deleted property
      parentProto = Object.getPrototypeOf parent
      if prop of parentProto
        curr = {}
        for key, value of parentProto
          unless key is prop
            curr[key] = if typeof value is 'object'
              create value
            else
              value
        # TODO Replace this with cross browser code
        parent.__proto__ = curr
    delete parent[prop]
    return obj

  lookup: lookup = (path, data, vers, options = {}) ->
    {pathType, setVer, speculative, dontFollowLastRef} = options
    curr = data
    currVer = vers
    currVer.ver = setVer if setVer

    props = path.split '.'
    path = ''
    data.$remainder = ''
    i = 0
    len = props.length

    while i < len
      prop = props[i++]
      parent = curr
      curr = curr[prop]

      parentVer = currVer
      unless currVer = currVer[prop]
        if setVer && pathType
          currVer = parentVer[prop] = {}
        else
          currVer = parentVer

      # Store the absolute path we are about to traverse
      path = if path then path + '.' + prop else prop

      if curr?
        if speculative && typeof curr is 'object' && !isSpeculative(curr)
          curr = parent[prop] = create curr
      else
        unless pathType
          data.$remainder = props.slice(i).join '.'
          break

        # If pathType is truthy, create empty parent objects implied by path
        curr = parent[prop] = if speculative
            if pathType is 'array' && i == len then createArray() else createObject()
          else
            if pathType is 'array' && i == len then [] else {}

      # Check for model references
      if ref = curr.$r
        break if i == len && dontFollowLastRef
        
        {currVer, obj: rObj} = lookup ref, data, vers, options
        dereffedPath = if data.$remainder then "#{data.$path}.#{data.$remainder}" else data.$path
        currVer.ver = setVer if setVer

        if key = curr.$k
          # keyVer reflects the version set via an array op
          # memVer reflects the version set via an op on a member
          #  or member subpath
          if Array.isArray keyObj = lookup(key, data, vers).obj
            if i < len
              prop = keyObj[props[i++]]
              path = dereffedPath + '.' + prop
              {currVer, obj: curr} = curr = lookup path, data, vers, {setVer}
            else
              curr = (lookup(dereffedPath + '.' + index, data, vers).obj for index in keyObj)
          else
            dereffedPath += '.' + keyObj
            curr = lookup(dereffedPath, data, vers, options).obj
            path = dereffedPath unless i == len
        else
          curr = rObj
          path = dereffedPath unless i == len
        
        if `curr == null` && !pathType
          # Return undefined if the reference points to nothing
          data.$remainder = props.slice(i).join '.'
          break
      else
        currVer.ver = setVer  if setVer
    
    data.$path = path
    return {currVer, parent, prop, obj: curr}

xtraArrMutConf =
  insertAfter:
    outOfBounds: (arr, [afterIndex, _]) ->
      return ! (-1 <= afterIndex <= arr.length-1)
    fn: (arr, [afterIndex, value]) ->
      return arr.splice afterIndex+1, 0, value
  insertBefore:
    outOfBounds: (arr, [beforeIndex,_]) ->
      return ! (0 <= beforeIndex <= arr.length)
    fn: (arr, [beforeIndex, value]) ->
      return arr.splice beforeIndex, 0, value
  remove:
    outOfBounds: (arr, [startIndex, _]) ->
      upperBound = if arr.length then arr.length-1 else 0
      return ! (0 <= startIndex <= upperBound)
    fn: (arr, [startIndex, howMany]) ->
      return arr.splice startIndex, howMany

for method, {compound, normalizeArgs} of arrMutators
  continue if compound
  Memory::[method] = do (method, normalizeArgs) ->
    if xtraConf = xtraArrMutConf[method]
      outOfBounds = xtraConf.outOfBounds
      fn = xtraConf.fn
    return ->
      {path, methodArgs, ver, data, options} = normalizeArgs arguments...
      options.pathType = 'array'
      options.setVer = ver unless options.speculative
      arr = lookup(path, data || @_data, @_vers, options).obj
      throw new Error 'Not an Array' unless Array.isArray arr
      throw new Error 'Out of Bounds' if outOfBounds? arr, methodArgs
      # TODO Array of references handling
      return if fn then fn arr, methodArgs else arr[method] methodArgs...

Memory::move = (path, from, to, ver, data, options = {}) ->
  data ||= @_data
  vers = @_vers
  value = lookup("#{path}.#{from}", data, vers).obj
  to += lookup(path, data, vers).obj.length if to < 0
  if from > to
    @insertBefore path, to, value, ver, data, options
    from++
  else
    @insertAfter path, to, value, ver, data, options
  @remove path, from, 1, ver, data, options
