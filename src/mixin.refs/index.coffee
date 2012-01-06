{mergeAll: merge} = require '../util'
pathParser = require '../pathParser'

mutators = {}

module.exports =

  onMixin: (_mutators) ->
      mutators = _mutators
      # for mutator, fn of _mutators
        # arrayMutators[mutator] = fn  if fn.type is 'array'

  init: ->
    model = this

    for mutator of mutators
      do (mutator) ->
        model.on mutator, ->
          model.emit 'mutator', mutator, arguments

    # TODO: Can this be removed somehow?
    @on 'beforeTxn', (method, args) ->
      return unless (path = args[0])?
      data = model._specModel()
      # Update the transaction's path with a dereferenced path.
      args[0] = model._dereference path, data

  proto:
    ref: (from, to, key) ->
      return @set from, (new Ref this, from, to, key).modelObj
    
    _dereference: (path, data) ->
      @_adapter.get path, data ||= @_specModel()
      if data.$remainder then data.$path + '.' + data.$remainder else data.$path

  accessors:
    getRef:
      type: 'basic'
      fn: (path) ->
        @_adapter.getRef path, @_specModel()


join = Array::join

Ref = (@model, @from, @to, @key) ->
  self = this
  self.modelObj = modelObj = {$r: to}
  self.listeners = []

  if key
    modelObj.$k = key
    self.addListener "#{to}.*", (match) ->
      keyPath = model.get(self.key).toString()
      remainder = match[1]
      return self.path() if remainder == keyPath
      # Test to see if the remainder starts with the keyPath
      index = keyPath.length + 1
      if remainder.substr(0, index) == keyPath + '.'
        remainder = remainder.substr index
        return self.path remainder
      # Don't emit another event if the keyPath is not matched
      return null
  else
    self.addListener "#{to}.*", (match) -> self.path match[1]
    self.addListener to, -> self.path()

  return

Ref:: =

  path: ->
    if arguments.length
      @from + '.' + join.call(arguments, '.')
    else
      @from
  
  addListener: (pattern, callback) ->
    {model, from, modelObj} = self = this
    re = pathParser.eventRegExp pattern
    self.listeners.push listener = (mutator, _arguments) ->
      args = _arguments[0]
      if re.test path = args[0]
        return self.destroy() if model.getRef(from) != modelObj
        args = args.slice()
        path = callback re.exec(path)
        return if path is null
        args[0] = path
        model.emit mutator, args, _arguments[1], _arguments[2]
    model.on 'mutator', listener

  destroy: ->
    model = @model
    for listener in @listeners
      model.removeListener 'mutator', listener


RefList = (@model, @from, @to, @key) ->
  self = this
  self.modelObj = modelObj = {$r: to, $k: key}
  self.listeners = []

  return


merge RefList::, Ref::


# ArrayRef = (@model, @obj, @ids) ->

#   model.on '*', "#{obj}.*.?*", (method, id, remainder, args..., isLocal, _with) ->
#     # TODO: Fix this when deleting / removing an item
#     index = indexOf model.get "#{obj}.#{id}"
#     path = @path(index, remainder)
#     model.emit method, [path, args...], isLocal, _with

#   model.on '*', "#{ids}.*.?*", (method, index, remainder, args..., isLocal, _with) ->
#     model.emit method, [@path(index, remainder), args...], isLocal, _with

#   model.on 'set', "(?:#{obj}|#{ids})", (value, isLocal, _with) ->
#     emit 'set', model, @path(), isLocal, _with

#   model.on 'push', 'ids', (item, isLocal, _with) ->
#     emit 'push', model


# ArrayRef:: = Ref::

# ArrayRef::indexOf = (item) ->
#     model = @model
#     obj = model.get @obj
#     ids = model.get @ids
#     for id, i in ids
#       return i if item == obj[id]

# ArrayRef::get = ->
#     model = @model
#     obj = model.get @obj
#     ids = model.get @ids
#     return obj[id] for id in ids
