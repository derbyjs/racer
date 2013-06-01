{expect} = require '../util'
Model = require '../../lib/Model'

describe 'ref', ->

  expectEvents = (pattern, model, done, events) ->
    model.on 'all', pattern, ->
      events.shift() arguments...
      done() unless events.length
    done() unless events?.length

  describe 'event emission', ->

    it 're-emits on a reffed path', (done) ->
      model = new Model
      model.ref '_page.color', '_page.colors.green'
      model.on 'change', '_page.color', (value) ->
        expect(value).to.equal '#0f0'
        done()
      model.set '_page.colors.green', '#0f0'

    it 'also emits on the original path', (done) ->
      model = new Model
      model.ref '_page.color', '_page.colors.green'
      model.on 'change', '_page.colors.green', (value) ->
        expect(value).to.equal '#0f0'
        done()
      model.set '_page.colors.green', '#0f0'

    it 're-emits on a child of a reffed path', (done) ->
      model = new Model
      model.ref '_page.color', '_page.colors.green'
      model.on 'change', '_page.color.*', (capture, value) ->
        expect(capture).to.equal 'hex'
        expect(value).to.equal '#0f0'
        done()
      model.set '_page.colors.green.hex', '#0f0'

    it 're-emits on a ref to a ref', (done) ->
      model = new Model
      model.ref '_page.myFavorite', '_page.color'
      model.ref '_page.color', '_page.colors.green'
      model.on 'change', '_page.myFavorite', (value) ->
        expect(value).to.equal '#0f0'
        done()
      model.set '_page.colors.green', '#0f0'

    it 're-emits on multiple reffed paths', (done) ->
      model = new Model
      model.set '_page.colors.green', '#0f0'
      model.ref '_page.favorites.my', '_page.colors.green'
      model.ref '_page.favorites.your', '_page.colors.green'

      expectEvents '_page.favorites**', model, done, [
        (capture, method, value, previous) ->
          expect(method).to.equal 'change'
          expect(capture).to.equal 'my'
          expect(value).to.equal '#0f1'
      , (capture, method, value, previous) ->
          expect(method).to.equal 'change'
          expect(capture).to.equal 'your'
          expect(value).to.equal '#0f1'
      ]
      model.set '_page.colors.green', '#0f1'

  describe 'get', ->

    it 'gets from a reffed path', ->
      model = new Model
      model.set '_page.colors.green', '#0f0'
      expect(model.get '_page.color').to.equal undefined
      model.ref '_page.color', '_page.colors.green'
      expect(model.get '_page.color').to.equal '#0f0'

    it 'gets from a child of a reffed path', ->
      model = new Model
      model.set '_page.colors.green.hex', '#0f0'
      model.ref '_page.color', '_page.colors.green'
      expect(model.get '_page.color').to.eql {hex: '#0f0'}
      expect(model.get '_page.color.hex').to.equal '#0f0'

    it 'gets from a ref to a ref', ->
      model = new Model
      model.ref '_page.myFavorite', '_page.color'
      model.ref '_page.color', '_page.colors.green'
      model.set '_page.colors.green', '#0f0'
      expect(model.get '_page.myFavorite').to.equal '#0f0'

