{expect} = require '../util'
RemoteDoc = require '../../lib/Model/RemoteDoc'
docs = require './docs'

describe 'RemoteDoc', ->

  createDoc = -> new RemoteDoc 'colors', 'green'

  # docs createDoc
  describe 'create', ->
    it.skip 'should set the collectionName and id properties', ->
      doc = createDoc()
      expect(doc.collectionName).to.equal 'colors'
      expect(doc.id).to.equal 'green'
