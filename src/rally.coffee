Model = require './Model'
modelServer = require './Model.server'
Store = require './Store'
browserify = require 'browserify'

# Add the server side functions to Model's prototype
for name, fn of modelServer
  Model::[name] = fn

clientJs = browserify.bundle
  require: __dirname + '/Model.js'

module.exports =
  store: store = new Store
  subscribe: (path, callback) ->
    # TODO: Accept a list of paths
    # TODO: Attach to an existing model
    # TODO: Support path wildcards, references, and functions
    model = new Model
    store.get path, (err, value, ver) ->
      callback err if err
      model._set path, value
      model._base = ver
      callback null, model
  js: -> clientJs
  unsubscribe: ->
    throw "Unimplemented"
  use: ->
    throw "Unimplemented"