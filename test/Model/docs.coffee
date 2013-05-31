{expect} = require '../util'

module.exports = (createDoc) ->

  describe 'get', ->

    it 'creates an undefined doc', ->
      doc = createDoc()
      expect(doc.get()).eql undefined

    it 'gets a defined doc', ->
      doc = createDoc()
      doc.set [], {id: 'green'}, ->
      expect(doc.get()).eql {id: 'green'}

    it 'gets a property on an undefined document', ->
      doc = createDoc()
      expect(doc.get ['id']).eql undefined

    it 'gets an undefined property', ->
      doc = createDoc()
      doc.set [], {}, ->
      expect(doc.get ['id']).eql undefined

    it 'gets a defined property', ->
      doc = createDoc()
      doc.set [], {id: 'green'}, ->
      expect(doc.get ['id']).eql 'green'

    it 'gets a false property', ->
      doc = createDoc()
      doc.set [], {id: 'green', shown: false}, ->
      expect(doc.get ['shown']).eql false

    it 'gets a null property', ->
      doc = createDoc()
      doc.set [], {id: 'green', shown: null}, ->
      expect(doc.get ['shown']).eql null

    it 'gets a method property', ->
      doc = createDoc()
      doc.set [], {empty: ''}, ->
      expect(doc.get ['empty', 'charAt']).eql ''.charAt

    it 'gets an array member', ->
      doc = createDoc()
      doc.set [], {rgb: [0, 255, 0]}, ->
      expect(doc.get ['rgb', '1']).eql 255

    it 'gets an array length', ->
      doc = createDoc()
      doc.set [], {rgb: [0, 255, 0]}, ->
      expect(doc.get ['rgb', 'length']).eql 3

  describe 'set', ->

    it 'sets an empty doc', ->
      doc = createDoc()
      previous = doc.set [], {}, ->
      expect(previous).equal undefined
      expect(doc.get()).eql {}

    it 'sets a property', ->
      doc = createDoc()
      previous = doc.set ['shown'], false, ->
      expect(previous).equal undefined
      expect(doc.get()).eql {shown: false}

    it 'sets a multi-nested property', ->
      doc = createDoc()
      previous = doc.set ['rgb', 'green', 'float'], 1, ->
      expect(previous).equal undefined
      expect(doc.get()).eql {rgb: {green: {float: 1}}}

    it 'sets on an existing document', ->
      doc = createDoc()
      previous = doc.set [], {}, ->
      expect(previous).equal undefined
      expect(doc.get()).eql {}
      previous = doc.set ['shown'], false, ->
      expect(previous).equal undefined
      expect(doc.get()).eql {shown: false}

    it 'returns the previous value on set', ->
      doc = createDoc()
      previous = doc.set ['shown'], false, ->
      expect(previous).equal undefined
      expect(doc.get()).eql {shown: false}
      previous = doc.set ['shown'], true, ->
      expect(previous).equal false
      expect(doc.get()).eql {shown: true}

    it 'creates an implied array on set', ->
      doc = createDoc()
      doc.set ['rgb', '2'], 0, ->
      doc.set ['rgb', '1'], 255, ->
      doc.set ['rgb', '0'], 127, ->
      expect(doc.get()).eql {rgb: [127, 255, 0]}
      
    it.skip 'creates an implied object on an array', (done) ->
      doc = createDoc()
      doc.set 'colors', []
      doc.set 'colors.0.value', 'green'
      expect(doc.get()).eql [{'value':'green'}]

  describe 'del', ->

    it 'can del on an undefined path without effect', ->
      doc = createDoc()
      previous = doc.del ['rgb', '2'], ->
      expect(previous).equal undefined
      expect(doc.get()).eql undefined

    it 'can del on a document', ->
      doc = createDoc()
      doc.set [], {}, ->
      previous = doc.del [], ->
      expect(previous).eql {}
      expect(doc.get()).eql undefined

    it 'can del on a nested property', ->
      doc = createDoc()
      doc.set ['rgb'], [
        {float: 0, int: 0}
        {float: 1, int: 255}
        {float: 0, int: 0}
      ], ->
      previous = doc.del ['rgb', '0', 'float'], ->
      expect(previous).eql 0
      expect(doc.get ['rgb']).eql [
        {int: 0}
        {float: 1, int: 255}
        {float: 0, int: 0}
      ]

  describe 'push', ->

    it 'can push on an undefined property', ->
      doc = createDoc()
      len = doc.push ['friends'], 'jim', ->
      expect(len).equal 1
      expect(doc.get()).eql {friends: ['jim']}

    it 'can push on a defined array', ->
      doc = createDoc()
      len = doc.push ['friends'], 'jim', ->
      expect(len).equal 1
      len = doc.push ['friends'], 'sue', ->
      expect(len).equal 2
      expect(doc.get()).eql {friends: ['jim', 'sue']}

    it 'throws a TypeError when pushing on a non-array', (done) ->
      doc = createDoc()
      doc.set ['friends'], {}, ->
      doc.push ['friends'], ['x'], (err) ->
        expect(err).a TypeError
        done()
