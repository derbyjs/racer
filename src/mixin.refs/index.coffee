{isServer} = require '../util'
{isPrivate} = require '../pathParser'
Ref = require './types/Ref'
RefList = require './types/RefList'
{derefPath} = require './util'

refs = module.exports =

  onMixin: (Klass) ->
    mutators = Klass.mutators
    basicMutators = Klass.basicMutators = {}
    arrayMutators = Klass.arrayMutators = {}
    for mutator, fn of mutators
      switch fn.type
        when 'basic' then basicMutators[mutator] = fn
        when 'array' then arrayMutators[mutator] = fn
    return

  init: ->
    model = @_root = this

    mutators = @constructor.mutators
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

    ref: (from, to, key) -> @_createRef Ref, from, to, key

    refList: (from, to, key) -> @_createRef RefList, from, to, key

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
      else if from._at
        from = from._at
      if to._at
        to = to._at
      model = @_root
      model._checkRefPath from, 'ref'
      {get, modelMethod} = new RefType model, from, to, key
      # Overridden on server; does nothing in browser
      refs.onCreateRef model, from, to, key, get, modelMethod
      model.set from, get
      return model.at from

    _getRef: (path) -> @_adapter.get path, @_specModel(), true


  onCreateRef: ->

  createFn: createFn = (model, path, inputs, callback, destroy) ->
    modelPassFn = model.pass('fn')
    run = ->
      value = callback (model.get input for input in inputs)...
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
