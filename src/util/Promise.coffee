util = require './index'
{finishAfter} = require './async'

util.Promise = Promise = module.exports = ->
  @callbacks = []
  @resolved = false
  return

Promise:: =

  resolve: (@err, @value) ->
    if @resolved
      throw new Error 'Promise has already been resolved'
    @resolved = true
    callback err, value for callback in @callbacks
    @callbacks = []
    return this

  on: (callback) ->
    if @resolved
      callback @err, @value
      return this
    @callbacks.push callback
    return this

  clear: ->
    @resolved = false
    delete @value
    delete @err
    return this

Promise.parallel = (promises) ->
  composite = new Promise
  i = promises.length
  finish = finishAfter i, (err) ->
    composite.resolve err
  while i--
    promises[i].on finish
  return composite
