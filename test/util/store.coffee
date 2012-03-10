{inspect} = require 'util'
{expect} = require './index'
racer = require '../../src/racer'
integration = require '../Store/integration'

exports.DEFAULT_RUN_OPTIONS = DEFAULT_RUN_OPTIONS =
  mode: 'lww'

runFor = (name, options, showOptions, callback) ->
  name += ' ' + inspect(options)  if showOptions
  describe name, ->
    store = null

    beforeEach (done) ->
      store = racer.createStore options
      return done()  if options.noFlush
      store.flush done

    unless options.noFlush
      afterEach (done) ->
        store.flush ->
          store.disconnect()
          done()

    callback -> store

exports.runFn = runFn = (defaultOptions, type, typeOptions) ->
  unless Array.isArray defaultOptions
    defaultOptions = [defaultOptions]

  run = (name, optionsList, callback) ->
    if typeof optionsList is 'function'
      # Support `run(name, callback)` -- i.e. no options
      callback = optionsList
      optionsList = defaultOptions
    else if !optionsList
      # Support `run(name)` -- i.e., default options
      optionsList = defaultOptions
    else if !Array.isArray(optionsList)
      # Support `run(name, {...}, cb)` -- i.e., one options
      optionsList = [optionsList]

    showOptions = optionsList.length > 1
    for options in optionsList
      runFor name, options, showOptions, callback

  run.allModes = allModes = []
  for mode in racer.Store.MODES
    options = {mode}
    options[type] = typeOptions  if type
    allModes.push options
    run[mode] = options

  return run

exports.run = runFn DEFAULT_RUN_OPTIONS

exports.adapter = (type, callback) ->
  (typeOptions, plugin, moreTests) ->
    describe "#{typeOptions.type} #{type} adapter", ->
      racer.use plugin  if plugin

      options = {}
      options[type] = typeOptions
      run = runFn options, type, typeOptions

      moreTests? run
      callback run
      integration run
