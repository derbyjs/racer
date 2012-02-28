{isPrivate} = require '../path'
{derefPath} = require './util'
Ref = require './Ref'
RefList = require './RefList'
createFn = require './createFn'
mutator = basicMutator = arrayMutator = null

module.exports = (racer) ->
  racer.mixin mixin

mixin =
  type: 'Model'

  server: __dirname + '/refs.server'

  events:

    mixin: (Model) ->
      {mutator, basicMutator, arrayMutator} = Model

    init: (model) ->
      model._root = model
      model._refsToBundle = []
      model._fnsToBundle = []

      for method of mutator
        do (method) -> model.on method, ([path]) ->
          model.emit 'mutator', method, path, arguments

      memory = model._memory
      model.on 'beforeTxn', (method, args) ->
        return unless path = args[0]

        obj = memory.get path, data = model._specModel()
        if fn = data.$deref
          args[0] = fn method, args, model, obj
        return

    bundle: (model) ->
      onLoad = model._onLoad

      for [from, get, item] in model._refsToBundle
        if model._getRef(from) == get
          onLoad.push item

      for item in model._fnsToBundle
        onLoad.push item if item

  proto:
    _getRef: (path) -> @_memory.get path, @_specModel(), true

    _checkRefPath: (from, type) ->
      @_memory.get from, data = @_specModel(), true
      unless isPrivate derefPath data, from
        throw new Error "cannot create #{type} on public path #{from}"
      return

    dereference: (path) ->
      @_memory.get path, data = @_specModel()
      return derefPath data, path

    ref: (from, to, key) -> @_createRef Ref, 'ref', from, to, key

    refList: (from, to, key) -> @_createRef RefList, 'refList', from, to, key

    _createRef: (RefType, modelMethod, from, to, key) ->
      if @_at
        key = to
        to = from
        from = @_at
      else if from._at
        from = from._at
      to = to._at  if to._at
      key = key._at  if key && key._at
      model = @_root
      model._checkRefPath from, 'ref'
      {get} = new RefType basicMutator, arrayMutator, model, from, to, key
      model.set from, get
      @_onCreateRef modelMethod, from, to, key, get
      return model.at from

    fn: (inputs..., callback) ->
      path = if @_at then @_at else inputs.shift()
      model = @_root
      model._checkRefPath path, 'fn'
      if typeof callback is 'string'
        callback = do new Function 'return ' + callback
      destroy = @_onCreateFn path, inputs, callback
      return createFn model, path, inputs, callback, destroy

    # Overridden on server; do nothing in browser
    _onCreateRef: ->
    _onCreateFn: ->
