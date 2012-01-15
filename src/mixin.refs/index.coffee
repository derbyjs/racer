{mergeAll, hasKeys, isServer} = require '../util'
{eventRegExp, isPrivate} = require '../pathParser'

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
    model = @_root

    for mutator of mutators
      do (mutator) ->
        model.on mutator, ([path]) ->
          model.emit 'mutator', mutator, path, arguments

    @on 'beforeTxn', (method, args) ->
      return unless path = args[0]

      obj = @_adapter.get path, data = @_specModel()
      if fn = data.$deref
        args[0] = fn method, args, model, obj
      return

  proto:
    dereference: (path) ->
      @_adapter.get path, data = @_specModel()
      return derefPath data, path

    ref: (from, to, key) ->
      return @_createRef Ref, from, to, key

    refList: (from, to, key) ->
      return @_createRef RefList, from, to, key

    fn: (inputs..., callback) ->
      path = if @_at then @_at else inputs.shift()
      model = @_root
      model._checkRefPath path, 'fn'
      if typeof callback is 'string'
        callback = do new Function 'return ' + callback
      return createFn model, path, inputs, callback

    _checkRefPath: (from, type) ->
      @_adapter.get from, data = @_specModel(), true
      unless isPrivate derefPath data, from
        throw new Error "cannot create #{type} on public path #{from}"
      return

    _createRef: (RefType, from, to, key) ->
      if @_at
        key = to
        to = from
        from = @_at
      model = @_root
      model._checkRefPath from, 'ref'
      {get} = new RefType model, from, to, key
      @set from, get
      return get

    _getRef: (path) -> @_adapter.get path, @_specModel(), true


  createFn: createFn = (model, path, inputs, callback, destroy) ->
    modelPassFn = model.pass('fn')
    run = ->
      value = callback (model.get input for input, i in inputs)...
      modelPassFn.set path, value
      return value
    out = run()

    # Create regular expression matching the path or any of its parents
    p = ''
    source = (for segment, i in path.split '.'
      "(?:#{p += if i then '\\.' + segment else segment})"
    ).join '|'
    reSelf = new RegExp '^' + source + '$'

    # Create regular expression matching any of the inputs or
    # child paths of any of the inputs
    source = ("(?:#{input}(?:\\..+)?)" for input in inputs).join '|'
    reInput = new RegExp '^' + source + '$'

    listener = model.on 'mutator', (mutator, mutatorPath, _arguments) ->
      return if _arguments[3] == 'fn'

      if reSelf.test(mutatorPath) && (test = model.get path) != out && (
        # Don't remove if both test and out are NaN
        test == test || out == out
      )
        model.removeListener 'mutator', listener
        destroy() if destroy
      else if reInput.test mutatorPath
        out = run()
      return

    return out

require './server' if isServer


lookupPath = (path, props, i) ->
  arr = props.slice i
  arr.unshift path
  return arr.join '.'

derefPath = (data, to) ->
  data.$deref?() || to

Ref = (@model, @from, to, key) ->
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
    re = eventRegExp pattern
    self.listeners.push listener = (mutator, path, _arguments) ->
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
  
  modelMethod: 'ref'


RefList = (@model, @from, to, key) ->
  @listeners = []

  unless from && to && key
    throw new Error 'invalid arguments for model.refList'

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
