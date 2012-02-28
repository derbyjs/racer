{eventRegExp} = require '../path'
{derefPath, lookupPath} = require './util'

Ref = module.exports = (basicMutator, arrayMutator, @model, @from, to, key) ->
  @listeners = []

  unless from && to
    throw new Error 'invalid arguments for model.ref'

  if key
    @get = (lookup, data, path, props, len, i) ->
      lookup to, data
      dereffed = derefPath data, to
      keyPath = lookup key, data
      currPath = lookupPath dereffed + '.' + keyPath, props, i
      curr = lookup currPath, data

      data.$deref = (method) ->
        if i == len && method of basicMutator then path else currPath
      return [curr, currPath, i]

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
    @get = (lookup, data, path, props, len, i) ->
      curr = lookup to, data
      dereffed = derefPath data, to
      currPath = lookupPath dereffed, props, i

      data.$deref = (method) ->
        if i == len && method of basicMutator then path else currPath
      return [curr, currPath, i]

    @addListener "#{to}.*", (match) -> from + '.' + match[1]
    @addListener to, -> from

  return

Ref:: =

  addListener: (pattern, callback) ->
    {model, from, get} = self = this
    re = eventRegExp pattern
    @listeners.push listener = (mutator, path, _arguments) ->
      if re.test path
        return self.destroy() if model._getRef(from) != get
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
