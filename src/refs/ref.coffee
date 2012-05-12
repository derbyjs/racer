{eventRegExp} = require '../path'
{derefPath, lookupPath} = require './util'
Model = require '../Model'

exports = module.exports = (model, from, to, key) ->
  throw new Error 'Missing `from` in `model.ref(from, to, key)`' unless from
  throw new Error 'Missing `to` in `model.ref(from, to, key)`' unless to

  if key
    return setupRefWithKey model, from, to, key

  return setupRefWithoutKey model, from, to

setupRefWithKey = (model, from, to, key) ->
  listeners = []

  getter = (lookup, data, path, props, len, i) ->
    lookup to, data
    dereffed = derefPath(data, to) + '.'
    data.$deref = null
    dereffed += lookup key, data
    curr = lookup dereffed, data
    currPath = lookupPath dereffed, props, i

    data.$deref = (method) ->
      if i == len && method of Model.basicMutator then path else currPath

    return [curr, currPath, i]

  addListener model, from, getter, listeners, "#{to}.*", (match) ->
    keyPath = model.get(key) + '' # Cast to string
    remainder = match[1]
    return from if remainder == keyPath
    # Test to see if the remainder starts with the keyPath
    index = keyPath.length
    if remainder[0..index] == keyPath + '.'
      remainder = remainder[index + 1 ..]
      return from + '.' + remainder
    # Don't emit another event if the keyPath is not matched
    return null

  addListener model, from, getter, listeners, key, (match, mutator, args) ->
    if mutator is 'set'
      args[1] = model.get to + '.' + args[1]
      args.out = model.get to + '.' + args.out
    else if mutator is 'del'
      args.out = model.get to + '.' + args.out
    return from

  return getter

setupRefWithoutKey = (model, from, to) ->
  listeners = []

  getter = (lookup, data, path, props, len, i) ->
    curr = lookup to, data
    dereffed = derefPath data, to
    currPath = lookupPath dereffed, props, i

    data.$deref = (method) ->
      if i == len && method of Model.basicMutator then path else currPath

    return [curr, currPath, i]

  addListener model, from, getter, listeners, "#{to}.*", (match) ->
    from + '.' + match[1]

  addListener model, from, getter, listeners, to, ->
    from

  return getter

exports.addListener =
addListener = (model, from, getter, listeners, pattern, callback) ->
  re = eventRegExp pattern
  listener = (mutator, path, _arguments) ->
    if re.test path
      if model._getRef(from) != getter
        # Clean up listeners
        for fn in listeners
          model.removeListener 'mutator', fn
        return
      args = _arguments[0].slice()
      args.out = _arguments[1]
      path = callback re.exec(path), mutator, args
      return if path is null
      args[0] = path
      model.emit mutator, args, args.out, _arguments[2], _arguments[3]
    return
  listeners.push listener
  model.on 'mutator', listener
