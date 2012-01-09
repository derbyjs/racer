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
      return unless path = args[0]

      data = @_specModel()
      delete data.$deref

      obj = @_adapter.get path, data
      if fn = data.$deref
        args[0] = fn data, method, args, this, obj

  proto:
    ref: (from, to, key) ->
      return @set from, (new Ref this, from, to, key).get

    refList: (from, to, key) ->
      return @set from, (new RefList this, from, to, key).get

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
    self.get = (lookup, data, path, i, len) ->
      lookup to, data
      currPath = lookupPath(data) + '.' + lookup(key, data)
      curr = lookup currPath, data
      
      data.$deref = if i == len
        (data, method) -> if method of basicMutators then path else currPath
      else
        (data) -> lookupPath data

      return [curr, currPath, i]

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
    self.get = (lookup, data, path, i, len) ->
      curr = lookup to, data
      currPath = lookupPath data

      data.$deref = if i == len
        (data, method) -> if method of basicMutators then path else currPath
      else
        (data) -> lookupPath data

      return [curr, currPath, i]

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


refListId = (obj) ->
  unless (id = obj.id)?
    throw new Error 'refList mutators require an id'
  return id

RefList = (@model, @from, @to, @key) ->
  self = this
  self.listeners = []

  self.get = (lookup, data, path, i, len, props) ->
    obj = lookup(to, data) || {}
    currPath = lookupPath data
    map = lookup key, data
    if i == len
      # TODO: deref fn

      if map
        curr = (obj[prop] for prop in map)
        return [curr, currPath, i]

    else
      index = props[i++]
      data.$deref = if i == len
        # Method is on an index of the refList
        (data, method, args, model, obj) ->
          # TODO: Additional model methods should be done atomically
          # with the original txn instead of making an additional txn

          if method is 'set'
            id = refListId args[1]
            if map
              model.set key + '.' + index, id
            else
              model.set key, [id]
            return currPath + '.' + id

          if method is 'del'
            id = refListId obj
            model.del key + '.' + index
            return currPath + '.' + id

          throw new Error 'Unsupported method on refList member'

      else
        (data) -> lookupPath data

      if map && (prop = map[index])?
        curr = obj[prop]
        return [curr, currPath + '.' + prop, i]

    return [undefined, currPath, i]

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
