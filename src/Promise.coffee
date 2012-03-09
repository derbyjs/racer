Promise = module.exports = ->
  @callbacks = []
  @errbacks = []
  return

Promise:: =
  resolve: (@value) ->
    if @resolved
      throw new Error 'Promise has already been resolved'
    @resolved = true
    @ok = true
    callback value for callback in @callbacks
    errback null, value for errback in @errbacks
    @callbacks = []
    @errbacks = []
    return this

  errResolve: (err, @value) ->
    if @resolved
      throw new Error 'Promise has already been resolved'
    @resolved = true
    if err
      @err = err
      throw err if @callbacks.length
      errback err, value for errback in @errbacks
    else
      @ok = true
      callback value for callback in @callbacks
      errback null, value for errback in @errbacks
    @callbacks = []
    @errbacks = []
    return this

  on: (callback) ->
    if @ok
      callback @value
      return this
    if @err
      throw @err
    @callbacks.push callback
    return this

  errback: (errback) ->
    if @resolved
      errback @err, @value
      return this
    @errbacks.push errback
    return this

  clear: ->
    delete @resolved
    delete @ok
    delete @value
    delete @err
    return this

Promise::callback = Promise::on

Promise.parallel = (promises) ->
  composite = new Promise
  if Array.isArray promises
    count = promises.length
    err = null
    for promise in promises
      promise.errback (_err) ->
        err ||= _err
        --count || composite.errResolve err
  return composite
