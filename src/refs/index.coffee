{isPrivate, regExpPathOrParent, regExpPathsOrChildren} = require '../path'
{derefPath} = require './util'
createRef = require './ref'
createRefList = require './refList'
{diffArrays} = require '../diffMatchPatch'
{isServer, equal} = require '../util'

racer = require '../racer'

exports = module.exports = (racer) ->
  racer.mixin mixin

exports.useWith = server: true, browser: true

mixin =
  type: 'Model'

  server: __dirname + '/refs.server'

  events:

    init: (model) ->
      # Used for model scopes
      model._root = model

      # [[from, get, item], ...]
      model._refsToBundle = []

      # [['fn', path, inputs..., cb.toString()], ...]
      model._fnsToBundle = []

      Model = model.constructor

      for method of Model.mutator
        do (method) -> model.on method, ([path]) ->
          model.emit 'mutator', method, path, arguments

      memory = model._memory
      model.on 'beforeTxn', (method, args) ->
        if path = args[0]
          # Dereference transactions to operate on their absolute path
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

    _ensurePrivateRefPath: (from, modelMethod) ->
      unless isPrivate @dereference(from, true)
        throw new Error "Cannot create #{modelMethod} on public path '#{from}'"

    dereference: (path, getRef = false) ->
      @_memory.get path, data = @_specModel(), getRef
      return derefPath data, path

    ref: (from, to, key) -> @_createRef createRef, 'ref', from, to, key

    refList: (from, to, key) -> @_createRef createRefList, 'refList', from, to, key

    _createRef: (refFactory, modelMethod, from, to, key) ->
      # Normalize `from`, `to`, `key` if we are a model scope
      if @_at
        key = to
        to = from
        from = @_at
      else if from._at
        from = from._at
      to = to._at  if to._at
      key = key._at  if key && key._at
      model = @_root

      model._ensurePrivateRefPath from, modelMethod
      get = refFactory model, from, to, key

      # Prevent emission of the next set event, since we are setting
      # the dereferencing function and not its value
      listener = model.on 'beforeTxn', (method, args) ->
        # Suppress emission of set events when setting a function,
        # which is what happens when a ref is created
        if method is 'set' && args[1] is get
          args.cancelEmit = true
          model.removeListener 'beforeTxn', listener
        return

      previous = model.set from, get
      # Emit a set event with the expected dereferenced values
      value = model.get from
      model.emit 'set', [from, value], previous, true, undefined

      # The server model adds [from, get, [modelMethod, from, to, key]]
      # to @_refsToBundle
      @_onCreateRef? modelMethod, from, to, key, get

      return model.at from

    # Defines a reactive value that depends on the paths represented by `inputs`, which
    # which are used by `fn` to re-calculate a return value every time any of the
    # `inputs` change.
    fn: (inputs..., fn) ->
      # Convert scoped models into paths
      for input, i in inputs
        inputs[i] = fullPath if fullPath = input._at
      # If we are a scoped model, scoped to @_at
      path = @_at || inputs.shift()
      model = @_root

      model._ensurePrivateRefPath path, 'fn'
      if typeof fn is 'string'
        fn = do new Function 'return ' + fn
      return model._createFn path, inputs, fn

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
      reSelf = regExpPathOrParent path
      reInput = regExpPathsOrChildren inputs

      destroy = @_onCreateFn? path, inputs, fn

      listener = @on 'mutator', (mutator, mutatorPath, _arguments) =>
        # Ignore mutations created by this reactive function
        return if _arguments[3] == listener

        # Remove reactive function if something else sets the value of its
        # output path. We get the current value here, since a mutator
        # might operate on the path or the parent path that does not actually
        # affect the reactive function. The equal function is true if the
        # objects are identical or if they are both NaN
        if reSelf.test(mutatorPath) && !equal(@get(path), currVal)
          @removeListener 'mutator', listener
          return destroy?()

        if reInput.test mutatorPath
          currVal = updateVal()

      model = @pass listener

      return do updateVal = =>
        prevVal = currVal
        currVal = fn (@get input for input in inputs)...

        # TODO: Investigate using array diffing
        # if Array.isArray(prevVal) && Array.isArray(currVal)
        #   diff = diffArrays prevVal, currVal
        #   for args in diff
        #     method = args[0]
        #     args[0] = path
        #     model[method] args...
        #   return currVal

        return currVal if equal prevVal, currVal
        model.set path, currVal
        return currVal
