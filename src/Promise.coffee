Promise = module.exports = ->
  @callbacks = []
  @resets = []
  return

Promise:: =
  on: (callback, scope) ->
    return callback @value unless @value is undefined
    callbacks = @callbacks
    callbacks[callbacks.length] = [callback, scope]
    @

  fulfill: (val) ->
    if @value isnt undefined
      throw new Error 'Promise has already been fulfilled'
    @value = val
    callback.call scope, val for [callback, scope] in @callbacks
    @callbacks = []
    @

  onReset: (callback, scope) ->
    resets = @resets
    resets[resets.length] = [callback, scope]

  reset: ->
    delete @value
    callback.call scope for [callback, scope] in @resets
    @resets = []
    @

Promise.parallel = (promises...) ->
  compositePromise = new Promise
  dependencies = promises.length
  promises.forEach (promise) ->
    promise.on -> --dependencies || compositePromise.fulfill(true)
    promise.onReset -> dependencies++ || compositePromise.reset()
  return compositePromise
