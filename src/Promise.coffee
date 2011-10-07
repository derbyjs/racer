Promise = module.exports = ->
  @callbacks = []
  @clearValueCallbacks = []
  return

Promise:: =
  on: (callback, scope) ->
    return callback.call scope, @value unless @value is undefined
    @callbacks.push [callback, scope]
    @

  fulfill: (val) ->
    if @value isnt undefined
      throw new Error 'Promise has already been fulfilled'
    @value = val
    callback.call scope, val for [callback, scope] in @callbacks
    @callbacks = []
    @

  onClearValue: (callback, scope) ->
    @clearValueCallbacks.push [callback, scope]
    @

  clearValue: ->
    delete @value
    cbs = @clearValueCallbacks
    callback.call scope for [callback, scope] in cbs
    @clearValueCallbacks = []
    @

Promise.parallel = (promises...) ->
  compositePromise = new Promise
  dependencies = promises.length
  for promise in promises
    promise.on -> --dependencies || compositePromise.fulfill(true)
    promise.onClearValue -> compositePromise.clearValue()
  return compositePromise
