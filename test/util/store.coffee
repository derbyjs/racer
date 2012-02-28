{inspect} = require 'util'
{expect} = require './index'
racer = require '../../src/racer'

defaultRunOptions = [mode: 'lww']

module.exports =
  run: (name, optionsList, callback) ->
    if typeof optionsList is 'function'
      callback = optionsList
      optionsList = defaultRunOptions
    else if !optionsList
      optionsList = defaultRunOptions

    for options in optionsList
      run name, options, callback

run = (name, options, callback) ->
  describe name + ' ' + inspect(options), ->
    store = null

    beforeEach (done) ->
      store = racer.createStore options
      store.flush done

    afterEach (done) ->
      store.flush ->
        store.disconnect()
        done()

    callback -> store
