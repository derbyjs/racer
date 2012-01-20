Promise = module.exports = (opts) ->
  @callbacks = []
  @errbacks = []
  @clearValueCallbacks = []
  if opts then for method, arg of opts
    @[method] arg
  return

Promise:: =
  fulfill: (args...) ->
    if @fulfilled
      throw new Error 'Promise has already been fulfilled'
    @fulfilled = true
    if args.length == 1
      @value = args[0]
    else
      @value = args
    callback.apply scope, args for [callback, scope] in @callbacks
    @callbacks = []
    @

  error: (err) ->
    if @err
      throw new Error 'Promise has already erred'
    @err = err
    throw err unless @errbacks.length
    callback.call scope, err for [callback, scope] in @errbacks
    @errbacks = []
    @

  resolve: (err, vals...) ->
    return @error err if err
    return @fulfill vals...
    @

  on: (callback, scope) ->
    return callback.call scope, @value if @fulfilled
    @callbacks.push [callback, scope]
    @

  errback: (callback, scope) ->
    return callback.call scope, @err if @err
    @errbacks.push [callback, scope]
    @

  bothback: (callback, scope) ->
    @errback callback, scope
    @callback (vals...) ->
      callback.call @, null, vals...
    , scope

  onClearValue: (callback, scope) ->
    @clearValueCallbacks.push [callback, scope]
    @

  clearValue: ->
    delete @value
    @fulfilled = false
    cbs = @clearValueCallbacks
    callback.call scope for [callback, scope] in cbs
    @clearValueCallbacks = []
    @

Promise::callback = Promise::on

Promise.parallel = (promises) ->
  compositePromise = new Promise
  if Array.isArray promises
    numDependencies = promises.length
    parallelVals = []
    for promise, i in promises
      do (i) ->
        promise.callback (vals...) ->
          parallelVals[i] = vals
          --numDependencies || compositePromise.fulfill parallelVals...
      promise.onClearValue -> compositePromise.clearValue()
  else
    numDependencies = Object.keys(promises).length
    valsByName = {}
    for name, promise of promises
      do (name) ->
        promise.callback (val) ->
          valsByName[name] = val
          --numDependencies || compositePromise.fulfill valsByName
      promise.onClearValue -> compositePromise.clearValue()
  return compositePromise

Promise.transform = (transformFn) ->
  transPromise = new Promise
  origTransFulfill = transPromise.fulfill
  transPromise.fulfill = (val) ->
    origTransFulfill.call @, transformFn val
  return transPromise
