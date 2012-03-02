{inspect} = require 'util'
{expect} = require './index'
racer = require '../../src/racer'

exports.DEFAULT_RUN_OPTIONS = DEFAULT_RUN_OPTIONS =
  mode: 'lww'

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

exports.runFn = runFn = (defaultOptions) ->
  unless Array.isArray defaultOptions
    defaultOptions = [defaultOptions]

  return (name, optionsList, callback) ->
    if typeof optionsList is 'function'
      callback = optionsList
      optionsList = defaultOptions
    else if !optionsList
      optionsList = defaultOptions
    else if !Array.isArray(optionsList)
      optionsList = [optionsList]

    showOptions = optionsList.length > 1
    for options in optionsList
      run name, options, showOptions, callback

exports.run = runFn DEFAULT_RUN_OPTIONS
