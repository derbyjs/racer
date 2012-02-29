{inspect} = require 'util'
{expect} = require './index'
racer = require '../../src/racer'

defaultRunOptions = [mode: 'lww']

module.exports =
  run: (name, optionsList, callback) ->
    switch typeof optionsList
      when 'array'
        showOptions = true
      when 'function'
        callback = optionsList
        optionsList = defaultRunOptions
      when 'object'
        optionsList = [optionsList]
      else
        optionsList = defaultRunOptions

    for options in optionsList
      run name, options, showOptions, callback

run = (name, options, showOptions, callback) ->
  name += ' ' + inspect(options)  if showOptions
  describe name, ->
    store = null

    beforeEach (done) ->
      store = racer.createStore options
      store.flush done

    afterEach (done) ->
      store.flush ->
        store.disconnect()
        done()

    callback -> store
