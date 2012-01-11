{merge, hasKeys} = require '../util'
pathParser = require '../pathParser'

mutators = {}
basicMutators = {}
arrayMutators = {}

module.exports =

  onMixin: (_mutators) ->
    mutators = _mutators
    for mutator, fn of _mutators
      switch fn.type
        when 'basic' then basicMutators[mutator] = fn
        when 'array' then arrayMutators[mutator] = fn
    return

  init: ->
    model = this

    for mutator of mutators
      do (mutator) ->
        model.on mutator, ->
          model.emit 'mutator', mutator, arguments

    @on 'beforeTxn', (method, args) ->
      return unless path = args[0]

      obj = @_adapter.get path, data = @_specModel()
      if fn = data.$deref
        args[0] = fn method, args, this, obj
      return

  proto:
    dereference: (path) ->
      @_adapter.get path, data = @_specModel()
      return derefPath data, path

    ref: (from, to, key) ->
      return @set from, (new Ref this, from, to, key).get

    refList: (from, to, key) ->
      return @set from, (new RefList this, from, to, key).get
  
  serverProto:
    ref: (from, to, key) ->
      model = this
      get = (new Ref this, from, to, key).get
      @on 'bundle', ->
        if model.getRef(from) == get
          args = if key then [from, to, key] else [from, to]
          model._onLoad.push ['ref', args]
      return @set from, get

    refList: (from, to, key) ->
      model = this
      get = (new RefList this, from, to, key).get
      @on 'bundle', ->
        if model.getRef(from) == get
          args = [from, to, key]
          model._onLoad.push ['refList', args]
      return @set from, get

  accessors:
    getRef:
      type: 'basic'
      fn: (path) -> @_adapter.get path, @_specModel(), true


lookupPath = (path, props, i) ->
  arr = props.slice i
  arr.unshift path
  return arr.join '.'

derefPath = (data, to) ->
  data.$deref?() || to

Ref = (@model, @from, to, key) ->
  @listeners = []

  if key
    @get = (lookup, data, path, props, len, i) ->
      lookup to, data
      dereffed = derefPath data, to
      keyPath = lookup key, data
      currPath = lookupPath dereffed + '.' + keyPath, props, i
      curr = lookup currPath, data

      data.$deref = (method) ->
        if i == len && method of basicMutators then path else currPath
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
        if i == len && method of basicMutators then path else currPath
      return [curr, currPath, i]

    @addListener "#{to}.*", (match) -> from + '.' + match[1]
    @addListener to, -> from

  return

Ref:: =

  addListener: (pattern, callback) ->
    {model, from, get} = self = this
    re = pathParser.eventRegExp pattern
    self.listeners.push listener = (mutator, _arguments) ->
      args = _arguments[0]
      if re.test path = args[0]
        return self.destroy() if model.getRef(from) != get
        args = args.slice()
        path = callback re.exec(path), mutator, args
        return if path is null
        args[0] = path
        model.emit mutator, args, _arguments[1], _arguments[2], _arguments[3]
    model.on 'mutator', listener

  destroy: ->
    model = @model
    for listener in @listeners
      model.removeListener 'mutator', listener


# TODO: Allow a name other than 'id' for the key id property?
refListId = (obj) ->
  unless (id = obj.id)?
    throw new Error 'refList mutators require an id'
  return id

RefList = (@model, @from, to, key) ->
  @listeners = []

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

        if method of arrayMutators
          # Handle index args if they are specified by id
          if indexArgs = arrayMutators[method].indexArgs
            for j in indexArgs
              continue unless (arg = args[j]) && (id = arg.id)?
              # Replace id arg with the current index for the given id
              for keyId, index in map
                if `keyId == id`
                  args[j] = index
                  break

          if j = mutators[method].insertArgs
            while arg = args[j]
              id = refListId arg
              # Set the object being inserted if it contains any properties
              # other than id
              model.set dereffed + '.' + id, arg  if hasKeys arg, 'id'
              args[j] = id
              j++
          return dereffedKey

        throw new Error 'Unsupported method on refList'

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
            id = refListId args[1]
            if map
              model.set dereffedKey + '.' + index, id
            else
              model.set dereffedKey, [id]
            return currPath + '.' + id

          if method is 'del'
            id = refListId obj
            model.del dereffedKey + '.' + index
            return currPath + '.' + id

          throw new Error 'Unsupported method on refList index'

      else
        # Method is on a child of the refList
        throw new Error 'Method on undefined refList child' unless prop
        currPath = lookupPath dereffed + '.' + prop, props, i

        data.$deref = -> currPath

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

merge RefList::, Ref::
