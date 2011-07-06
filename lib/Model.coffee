_ = require './util'
ClientModel = require './client/Model'
ServerModel = require './client/ServerModel'

# Note that Model is written as an object constructor for testing purposes,
# but it is not intended to be instantiated multiple times in use. Therefore,
# all functions are simply defined in a closure, which would be inefficient
# if multiple model instantiations were created.

Model = module.exports = ->
  return new (_.onServer ? ClientModel : ServerModel)()
