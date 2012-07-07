{expect} = require '../util'
{Model} = require('../../lib/racer').protected
sinon = require 'sinon'

describe 'Model', ->
  describe '#context', ->
    it 'should default Model#currContext to "default" before the block', ->
      model = new Model
      expect(model.currContext).to.eql name: 'default'

    it 'should set Model#currContext inside the block', ->
      model = new Model
      model.context 'inception', ->
        expect(model.currContext).to.eql name: 'inception'

    it 'should set Model#currContext to "default" after the block', ->
      model = new Model
      expect(model.currContext).to.eql name: 'default'

  describe '#eachContext(callback)', ->
    it 'should pass every context we have defined to a callback', ->
      model = new Model
      model.context 'huey', ->
      model.context 'duey', ->
      model.context 'luey', ->

      spy = sinon.spy()
      model.eachContext spy

      expect(spy).to.be.calledWithEql [name: 'huey']
      expect(spy).to.be.calledWithEql [name: 'duey']
      expect(spy).to.be.calledWithEql [name: 'luey']

      expect(spy).to.have.callCount(3)

    it 'should invoke the callback upon subsequent Model#context calls', ->
      model = new Model
      spy = sinon.spy()
      model.context 'trolololo'
      model.context 'trololo'

      model.eachContext spy

      expect(spy).to.be.calledWithEql [name: 'trololo']
      expect(spy).to.be.calledWithEql [name: 'trolololo']

      model.context 'word'
      expect(spy).to.be.calledWithEql [name: 'word']
      expect(spy).to.have.callCount(3)

    it 'should not invoke the callback upon subsequent Model#context calls that were also made before eachContext', ->
      model = new Model
      spy = sinon.spy()
      model.context 'word'
      model.eachContext spy

      expect(spy).to.be.calledWithEql [name: 'word']

      model.context 'word'
      expect(spy).to.have.callCount(1)
