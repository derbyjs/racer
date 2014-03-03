{expect} = require '../util'
Model = require './MockConnectionModel'
RemoteDoc = require '../../lib/Model/RemoteDoc'
docs = require './docs'

describe 'RemoteDoc', ->

  createDoc = ->
    model = new Model
    model.createConnection()
    model.data.colors = {}
    return new RemoteDoc model, 'colors', 'green'

  describe 'create', ->
    it 'should set the collectionName and id properties', ->
      doc = createDoc()
      expect(doc.collectionName).to.equal 'colors'
      expect(doc.id).to.equal 'green'

  docs createDoc
