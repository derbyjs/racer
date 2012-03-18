{eventRegExp} = require '../path'
{derefPath, lookupPath} = require './util'
Model = require '../Model'

Ref = module.exports = (@model, @from, @to, @key) ->
  @listeners = []

  throw new Error 'Missing `from` in `model.ref(from, to, key)`' unless from
  throw new Error 'Missing `to` in `model.ref(from, to, key)`' unless to

  if key
    @get = => @_getWithKey arguments...

    @addListener "#{to}.*", (match) ->
      keyPath = model.get(key).toString()
      remainder = match[1]
      return from if remainder == keyPath
      # Test to see if the remainder starts with the keyPath
      index = keyPath.length + 1
      if remainder.substr(0, index) == keyPath + '.'
        remainder = remainder.substr index
        return from + '.' + remainder
      # Don't emit another event if the keyPath is not matched
      return null

  else
    @get = => @_getWithoutKey arguments...

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
        path = callback re.exec(path), mutator, args
        return if path is null
        args[0] = path
        model.emit mutator, args, _arguments[1], _arguments[2], _arguments[3]
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
    dereffed = derefPath data, to
    keyPath = lookup @key, data
    currPath = lookupPath dereffed + '.' + keyPath, props, i
    curr = lookup currPath, data

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
