Ref = require './Ref'
{mergeAll, hasKeys} = require '../../util'
{derefPath, lookupPath} = require '../util'

module.exports = RefList = (@model, @from, to, key) ->
  @listeners = []

  unless from && to && key
    throw new Error 'invalid arguments for model.refList'

  {mutators, basicMutators, arrayMutators} = @model.constructor

  @get = (lookup, data, path, props, len, i) ->
    obj = lookup(to, data) || {}
    dereffed = derefPath data, to
    data.$deref = null
    map = lookup key, data
    dereffedKey = derefPath data, key
    if i == len
      # Method is on the refList itself
      currPath = lookupPath dereffed, props, i

      data.$deref = (method, args, model) ->
        return path if method of basicMutators

        if arrayMutator = arrayMutators[method]
          # Handle index args if they are specified by id
          if indexArgs = arrayMutator.indexArgs
            for j in indexArgs
              continue unless (arg = args[j]) && (id = arg.id)?
              # Replace id arg with the current index for the given id
              for keyId, index in map
                if `keyId == id`
                  args[j] = index
                  break

          if j = arrayMutator.insertArgs
            while arg = args[j]
              id = arg.id = model.id()  unless (id = arg.id)?
              # Set the object being inserted if it contains any properties
              # other than id
              model.set dereffed + '.' + id, arg  if hasKeys arg, 'id'
              args[j] = id
              j++
          return dereffedKey

        throw new Error method + ' unsupported on refList'

      if map
        curr = (obj[prop] for prop in map)
        return [curr, currPath, i]

      return [undefined, currPath, i]

    else
      index = props[i++]

      if map && (prop = map[index])?
        curr = obj[prop]

      if i == len
        # Method is on an index of the refList
        currPath = lookupPath dereffed, props, i

        data.$deref = (method, args, model, obj) ->
          # TODO: Additional model methods should be done atomically
          # with the original txn instead of making an additional txn

          if method is 'set'
            value = args[1]
            id = value.id = model.id()  unless (id = value.id)?
            if map
              model.set dereffedKey + '.' + index, id
            else
              model.set dereffedKey, [id]
            return currPath + '.' + id

          if method is 'del'
            unless (id = obj.id)?
              throw new Error 'Cannot delete refList item without id'
            model.del dereffedKey + '.' + index
            return currPath + '.' + id

          throw new Error method + ' unsupported on refList index'

      else
        # Method is on a child of the refList
        currPath = lookupPath dereffed + '.' + prop, props, i

        data.$deref = (method) ->
          if method && `prop == null`
            throw new Error method + ' on undefined refList child ' + props.join('.')
          currPath

      return [curr, currPath, i]

  @addListener key, (match, method, args) ->
    if i = mutators[method].insertArgs
      while (id = args[i])?
        args[i] = model.get(to + '.' + id)
        i++
    return from
  @addListener "#{to}.*", (match) ->
    id = match[1]
    if ~(i = id.indexOf '.')
      remainder = id.substr i + 1
      id = id.substr 0, i
    if map = model.get key
      for value, i in map
        if `value == id`
          found = true
          break
    return null unless found
    return if remainder then "#{from}.#{i}.#{remainder}" else "#{from}.#{i}"

  return

mergeAll RefList::, Ref::,
  modelMethod: 'refList'
