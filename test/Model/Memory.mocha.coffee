{expect} = require '../util'
Memory = require '../../lib/Model/Memory'

describe 'Memory: Local document', ->

  createDoc = -> (new Memory).getOrCreateDoc '_colors', 'green'

  describe 'get', ->

    it 'gets an undefined doc', ->
      doc = (new Memory).getDoc '_colors', 'green'
      expect(doc).eql undefined

    it 'creates an undefined doc', ->
      doc = createDoc()
      expect(doc.get()).eql undefined

    it 'gets a defined doc', ->
      doc = createDoc()
      doc.set [], {id: 'green'}, ->
      expect(doc.get()).eql {id: 'green'}
