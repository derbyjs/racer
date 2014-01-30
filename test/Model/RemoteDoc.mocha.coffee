{expect} = require '../util'
Model = require '../../lib/Model'
RemoteDoc = require '../../lib/Model/RemoteDoc'
docs = require './docs'
share = require 'share'

Model.prototype._createConnection = ->
  socketMock =
    send: (message) ->
    close: ->
    onmessage: ->
    onclose: ->
    onerror: ->
    onopen: ->
    onconnecting: ->
  @root.socket = socketMock
  @root.shareConnection = new share.client.Connection(socketMock)
  @_set(['$connection', 'state'], 'connected')
  @_createChannel()

describe 'RemoteDoc', ->

  model = null
  createDoc = -> new RemoteDoc model, 'colors', 'green'

  beforeEach ->
    model = new Model
    model._createConnection()
    model.data =
      colors: {}

  describe 'create', ->
    it 'should set the collectionName and id properties', ->
      doc = createDoc()
      expect(doc.collectionName).to.equal 'colors'
      expect(doc.id).to.equal 'green'

  docs createDoc
