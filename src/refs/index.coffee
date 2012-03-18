{isPrivate, regExpMatchingPathOrParent, regExpMatchingPathsOrChildren} = require '../path'
{derefPath} = require './util'
Ref = require './Ref'
RefList = require './RefList'
{diffArrays} = require '../diffMatchPatch'
{deepEqual, equalsNaN} = require '../util'
mutator = null

module.exports = (racer) ->
  racer.mixin mixin

mixin =
  type: 'Model'

  server: __dirname + '/refs.server'

  events:

    mixin: (Model) ->
      {mutator} = Model

    init: (model) ->
      # Used for model scopes
      model._root = model

      # [[from, get, item], ...]
      model._refsToBundle = []

      # [['fn', path, inputs..., cb.toString()], ...]
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

      return

  proto:
    _getRef: (path) -> @_memory.get path, @_specModel(), true

    _ensurePrivateRefPath: (from, type) ->
      unless isPrivate @dereference(from, true)
        throw new Error "cannot create #{type} on public path '#{from}'"
      return

    dereference: (path, getRef = false) ->
      @_memory.get path, data = @_specModel(), getRef
      return derefPath data, path

    ref: (from, to, key) -> @_createRef Ref, 'ref', from, to, key

    refList: (from, to, key) ->
      @_createRef RefList, 'refList', from, to, key

    _createRef: (RefType, modelMethod, from, to, key) ->
      # Normalize from, to, key if we are a model scope
      if @_at
        key = to
        to = from
        from = @_at
      else if from._at
        from = from._at
      to = to._at  if to._at
      key = key._at  if key && key._at
      model = @_root

      model._ensurePrivateRefPath from, 'ref'
      {get} = new RefType model, from, to, key
      model.set from, get

      # The server model adds [from, get, [modelMethod, from, to, key]]
      # to @_refsToBundle
      @_onCreateRef modelMethod, from, to, key, get

      return model.at from

    # Defines a reactive value that depends on `inputs`, which are used by
    # `callback` to re-calculate a return value every time any of the `inputs`
    # change.
    fn: (inputs..., fn) ->
      # Convert scoped models into paths
      for input, i in inputs
        inputs[i] = input._at || input
      # If we are a scoped model, scoped to @_at
      path = @_at || inputs.shift()
      model = @_root

      model._ensurePrivateRefPath path, 'fn'
      if typeof fn is 'string'
        fn = do new Function 'return ' + fn
      return model._createFn path, inputs, fn

    # Overridden on server; do nothing in browser
    _onCreateRef: ->
    _onCreateFn: ->

    # @param {String} path to the reactive value
    # @param {[String]} inputs is a list of paths from which the reactive value is
    #                   calculated
    # @param {Function} fn returns the reactive value at `path` calculated from the
    #                   values at the paths defined by `inputs`
    # @param {undefined} `prevVal` is never passed into the function. It's included
    #                    as a function parameter, so we can have it as a variable
    #                    lexically within the function body without having to declare
    #                    `var prevVal`; this is nice for coffee-script.
    # @param {undefined} `currVal` is never passed into the function, for the same
    #                    reasons `prevVal` is never passed in.
    _createFn: (path, inputs, fn, destroy, prevVal, currVal) ->
      # Regular expression matching the path or any of its parents
      reSelf = regExpMatchingPathOrParent path

      # Regular expression matching any of the inputs or their children paths
      reInput = regExpMatchingPathsOrChildren inputs

      destroy = @_onCreateFn path, inputs, fn

      listener = @on 'mutator', (mutator, mutatorPath, _arguments) =>
        return if _arguments[3] == 'fn'

        if reSelf.test(mutatorPath) && !equalsNaN currVal
          @removeListener 'mutator', listener
          return destroy?()
        if reInput.test mutatorPath
          return process.nextTick -> currVal = updateVal()

      modelPassFn = @pass 'fn'

      return do updateVal = =>
        prevVal = currVal
        currVal = fn (@get input for input in inputs)...

        if Array.isArray(prevVal) && Array.isArray(currVal)
          diff = diffArrays prevVal, currVal
          for args in diff
            method = args[0]
            args[0] = path
            modelPassFn[method] args...
          return currVal

        return currVal if deepEqual prevVal, currVal
        modelPassFn.set path, currVal
        return currVal
