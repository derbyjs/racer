{expect} = require '../util'
Model = require '../../lib/Model'

describe 'Model events', ->

  describe 'mutator events', ->

    it 'calls earlier listeners in the order of mutations', (done) ->
      model = (new Model).at '_page'
      expectedPaths = ['a', 'b', 'c']
      model.on 'change', '**', (path) ->
        expect(path).to.equal expectedPaths.shift()
        done() unless expectedPaths.length
      model.on 'change', 'a', ->
        model.set 'b', 2
      model.on 'change', 'b', ->
        model.set 'c', 3
      model.set 'a', 1

    it 'calls later listeners in the order of mutations', (done) ->
      model = (new Model).at '_page'
      model.on 'change', 'a', ->
        model.set 'b', 2
      model.on 'change', 'b', ->
        model.set 'c', 3
      expectedPaths = ['a', 'b', 'c']
      model.on 'change', '**', (path) ->
        expect(path).to.equal expectedPaths.shift()
        done() unless expectedPaths.length
      model.set 'a', 1
