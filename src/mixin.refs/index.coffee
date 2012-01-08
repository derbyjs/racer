{mergeAll: merge} = require '../util'
pathParser = require '../pathParser'

mutators = {}
basicMutators = {}

module.exports =

  onMixin: (_mutators) ->
      mutators = _mutators
      for mutator, fn of _mutators
        switch fn.type
          when 'basic' then basicMutators[mutator] = fn

  init: ->
    model = this

    for mutator of mutators
      do (mutator) ->
        model.on mutator, ->
          model.emit 'mutator', mutator, arguments

    @on 'beforeTxn', (method, args) ->
      console.log args
      return unless path = args[0]
      args[0] = model._dereference path, (method of basicMutators)
      console.log args

  proto:
    ref: (from, to, key) ->
      return @set from, (new Ref this, from, to, key).get

    refList: (from, to, key) ->
      return @set from, (new RefList this, from, to, key).get

    _dereference: (path, getPath) ->
      @_adapter.get path, data = @_specModel()
      path = if getPath then data.$path else data.$refPath
      return if remainder = data.$remainder then path + '.' + remainder else path

  accessors:
    getRef:
      type: 'basic'
      fn: (path) ->
        @_adapter.getRef path, @_specModel()


join = Array::join

lookupPath = (data) ->
  path = data.$path
  return if remainder = data.$remainder then path + '.' + remainder else path

Ref = (@model, @from, @to, @key) ->
  self = this
  self.listeners = []

  if key
    self.get = (lookup, data) ->
      lookup to, data
      path = lookupPath data
      path += '.' + lookup key, data
      curr = lookup path, data
      return [curr, path]

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
    self.get = (lookup, data) ->
      curr = lookup to, data
      path = lookupPath data
      return [curr, path]

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
    {model, from, get} = self = this
    re = pathParser.eventRegExp pattern
    self.listeners.push listener = (mutator, _arguments) ->
      args = _arguments[0]
      if re.test path = args[0]
        return self.destroy() if model.getRef(from) != get
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
  self.listeners = []

  self.get = (lookup, data) ->
    obj = lookup to, data
    path = lookupPath data
    if map = lookup key, data
      curr = (obj[prop] for prop in map)
      return [curr, path]
    return [undefined, path]

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
