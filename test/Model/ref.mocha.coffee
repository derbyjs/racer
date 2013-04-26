{expect} = require '../util'
Model = require '../../lib/Model'

describe 'ref', ->

  describe 'event emission', ->

    it 're-emits on a reffed path', (done) ->
      model = new Model
      model.ref '_color', '_colors.green'
      model.on 'change', '_color', (value) ->
        expect(value).to.equal '#0f0'
        done()
      model.set '_colors.green', '#0f0'

    it 'also emits on the original path', (done) ->
      model = new Model
      model.ref '_color', '_colors.green'
      model.on 'change', '_colors.green', (value) ->
        expect(value).to.equal '#0f0'
        done()
      model.set '_colors.green', '#0f0'

    it 're-emits on a child of a reffed path', (done) ->
      model = new Model
      model.ref '_color', '_colors.green'
      model.on 'change', '_color.*', (capture, value) ->
        expect(capture).to.equal 'hex'
        expect(value).to.equal '#0f0'
        done()
      model.set '_colors.green.hex', '#0f0'

    it 're-emits on a ref to a ref', (done) ->
      model = new Model
      model.ref '_myFavorite', '_color'
      model.ref '_color', '_colors.green'
      model.on 'change', '_myFavorite', (value) ->
        expect(value).to.equal '#0f0'
        done()
      model.set '_colors.green', '#0f0'

  describe 'get', ->

    it 'gets from a reffed path', ->
      model = new Model
      model.set '_colors.green', '#0f0'
      expect(model.get '_color').to.equal undefined
      model.ref '_color', '_colors.green'
      expect(model.get '_color').to.equal '#0f0'

    it 'gets from a child of a reffed path', ->
      model = new Model
      model.set '_colors.green.hex', '#0f0'
      model.ref '_color', '_colors.green'
      expect(model.get '_color').to.eql {hex: '#0f0'}
      expect(model.get '_color.hex').to.equal '#0f0'

    it 'gets from a ref to a ref', ->
      model = new Model
      model.ref '_myFavorite', '_color'
      model.ref '_color', '_colors.green'
      model.set '_colors.green', '#0f0'
      expect(model.get '_myFavorite').to.equal '#0f0'
