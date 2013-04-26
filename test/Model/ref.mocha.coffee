{expect} = require '../util'
Model = require '../../lib/Model'

describe 'ref', ->

  describe 'event emission', ->

    it 're-emits a change on a reffed path', (done) ->
      model = new Model
      model.ref '_color', '_colors.green'
      model.on 'change', '_color', (value) ->
        expect(value).to.equal '#0f0'
        done()
      model.set '_colors.green', '#0f0'

    it 'also emits a change on the original path', (done) ->
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
