_ = require './util'
ClientModel = require './client/Model'
ServerModel = require './server/Model'

# Note that Model is written as an object constructor for testing purposes,
# but it is not intended to be instantiated multiple times in use. Therefore,
# all functions are simply defined in a closure, which would be inefficient
# if multiple model instantiations were created.

Model = module.exports = ->
  if _.onServer then new ServerModel() else new ClientModel()
