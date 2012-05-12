{mergeAll, hasKeys} = require '../util'
{derefPath, lookupPath} = require './util'
Model = require '../Model'
{addListener} = ref = require './ref'

module.exports = (model, from, to, key) ->
  unless from && to && key
    throw new Error 'Invalid arguments for model.refList'

  listeners = []
  arrayMutators = Model.arrayMutator

  getter = createGetter from, to, key

  addListener model, from, getter, listeners, key, (match, method, args) ->
    if i = arrayMutators[method]?.insertArgs
      while (id = args[i])?
        args[i] = model.get(to + '.' + id)
        i++
    return from

  addListener model, from, getter, listeners, "#{to}.*", (match) ->
    id = match[1]
    if ~(i = id.indexOf '.')
      remainder = id.substr i + 1
      id = id.substr 0, i
    if pointerList = model.get key
      for value, i in pointerList
        if `value == id`
          found = true
          break
    return null unless found
    return if remainder then "#{from}.#{i}.#{remainder}" else "#{from}.#{i}"

  return getter

createGetter = (from, to, key) ->
  # This represents a ref function that is assigned as the value of the node
  # located at `path` in `data`
  #
  # @param {Function} lookup is the Memory lookup function
  # @param {Object} data is the speculative or non-speculative data tree
  # @param {String} path is the current path to the ref function
  # @param {[String]} props is the chain of properties representing a full
  #                   path, of which path may be just a sub path
  # @param {Number} i is the array index of props that we are currently at
  # @return {Array} [evaled, path, i] where 
  getter = (lookup, data, path, props, len, i) ->
    basicMutators = Model.basicMutator
    arrayMutators = Model.arrayMutator

    obj = lookup(to, data) || {}
    dereffed = derefPath data, to
    data.$deref = null
    pointerList = lookup key, data
    dereffedKey = derefPath data, key
    if i == len
      # Method is on the refList itself
      currPath = lookupPath dereffed, props, i

      data.$deref = (method, args, model) ->
        return path if method of basicMutators

        if mutator = arrayMutators[method]
          # Handle index args if they are specified by id
          if indexArgs = mutator.indexArgs
            for j in indexArgs
              continue unless (arg = args[j]) && (id = arg.id)?
              # Replace id arg with the current index for the given id
              for keyId, index in pointerList
                if `keyId == id`
                  args[j] = index
                  break

          if j = mutator.insertArgs
            while arg = args[j]
              id = arg.id = model.id()  unless (id = arg.id)?
              # Set the object being inserted if it contains any properties
              # other than id
              model.set dereffed + '.' + id, arg  if hasKeys arg, 'id'
              args[j] = id
              j++
          return dereffedKey

        throw new Error method + ' unsupported on refList'
      # end of data.$deref function

      if pointerList
        curr = (obj[prop] for prop in pointerList)
        return [curr, currPath, i]

      return [undefined, currPath, i]

    else
      index = props[i++]

      if pointerList && (prop = pointerList[index])?
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
            if pointerList
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
