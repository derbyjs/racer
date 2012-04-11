{eventRegExp} = require '../path'
{derefPath, lookupPath} = require './util'
Model = require '../Model'

Ref = module.exports = (@model, @from, @to, @key) ->
  @listeners = []

  throw new Error 'Missing `from` in `model.ref(from, to, key)`' unless from
  throw new Error 'Missing `to` in `model.ref(from, to, key)`' unless to

  # Wrap so that get can be called anonymously
  @get = (lookup, data, path, props, len, i) =>
    @_get lookup, data, path, props, len, i

  if key
    @_get = @_getWithKey

    @addListener "#{to}.*", (match) ->
      keyPath = model.get(key) + ''  # Cast value to a string
      remainder = match[1]
      return from if remainder == keyPath
      # Test to see if the remainder starts with the keyPath
      index = keyPath.length
      if remainder[0..index] == keyPath + '.'
        remainder = remainder.slice index + 1
        return from + '.' + remainder
      # Don't emit another event if the keyPath is not matched
      return null

    @addListener key, (match, mutator, args) ->
      # When the key is set, emit a set event using the values
      # for the new and previous keys
      if mutator is 'set'
        args[1] = model.get to + '.' + args[1]
        args.out = model.get to + '.' + args.out
      else if mutator is 'del'
        args.out = model.get to + '.' + args.out
      return from

  else
    @_get = @_getWithoutKey

    @addListener "#{to}.*", (match) -> from + '.' + match[1]
    @addListener to, -> from

  return

Ref:: =

  addListener: (pattern, callback) ->
    {model, from, get} = this
    re = eventRegExp pattern
    @listeners.push listener = (mutator, path, _arguments) =>
      if re.test path
        return @destroy() if model._getRef(from) != get
        args = _arguments[0].slice()
        args.out = _arguments[1]
        path = callback re.exec(path), mutator, args
        return if path is null
        args[0] = path
        model.emit mutator, args, args.out, _arguments[2], _arguments[3]
      return
    model.on 'mutator', listener

  destroy: ->
    model = @model
    for listener in @listeners
      model.removeListener 'mutator', listener
    return

  _getWithKey: (lookup, data, path, props, len, i) ->
    to = @to
    lookup to, data
    dereffed = derefPath(data, to) + '.'
    data.$deref = null
    dereffed += lookup(@key, data)
    curr = lookup dereffed, data
    currPath = lookupPath dereffed, props, i

    data.$deref = (method) ->
      if i == len && method of Model.basicMutator then path else currPath
    return [curr, currPath, i]

  _getWithoutKey: (lookup, data, path, props, len, i) ->
    to = @to
    curr = lookup to, data
    dereffed = derefPath data, to
    currPath = lookupPath dereffed, props, i

    data.$deref = (method) ->
      if i == len && method of Model.basicMutator then path else currPath
    return [curr, currPath, i]
