{expect} = require '../util'
LocalDoc = require '../../lib/Model/LocalDoc'
docs = require './docs'

describe 'LocalDoc', ->

  createDoc = -> new LocalDoc '_colors', 'green'

  describe 'create', ->
    it 'should set the collectionName and id properties', ->
      doc = createDoc()
      expect(doc.collectionName).to.equal '_colors'
      expect(doc.id).to.equal 'green'

  docs createDoc
