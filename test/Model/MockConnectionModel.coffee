share = require 'share'
Model = require '../../lib/Model'

# Mock up a connection with a fake socket
module.exports = MockConnectionModel = ->
  Model.apply this, arguments
MockConnectionModel:: = Object.create Model::
MockConnectionModel::createConnection = ->
  socketMock =
    send: (message) ->
    close: ->
    onmessage: ->
    onclose: ->
    onerror: ->
    onopen: ->
    onconnecting: ->
  @root.shareConnection = new share.client.Connection(socketMock)
