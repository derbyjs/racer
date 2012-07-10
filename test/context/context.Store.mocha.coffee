{expect} = require '../util'
racer = require '../../lib/racer'
sinon = require 'sinon'

describe 'Store', ->
  describe '#context', ->
    it 'should default store#currContext to "default" before the block', ->
      store = racer.createStore()
      expect(store.currContext).to.eql name: 'default'

    it 'should set store#currContext inside the block', ->
      store = racer.createStore()
      store.context 'inception', ->
        expect(store.currContext).to.eql name: 'inception'

    it 'should set store#currContext to "default" after the block', ->
      store = racer.createStore()
      expect(store.currContext).to.eql name: 'default'

  describe '#eachContext(callback)', ->
    it 'should pass every context we have defined to a callback', ->
      store = racer.createStore()
      store.context 'huey', ->
      store.context 'duey', ->
      store.context 'luey', ->

      spy = sinon.spy()
      store.eachContext spy

      expect(spy).to.be.calledWithEql [name: 'huey']
      expect(spy).to.be.calledWithEql [name: 'duey']
      expect(spy).to.be.calledWithEql [name: 'luey']

      expect(spy).to.have.callCount(3)

    it 'should invoke the callback upon subsequent store#context calls', ->
      store = racer.createStore()
      spy = sinon.spy()
      store.context 'trolololo'
      store.context 'trololo'

      store.eachContext spy

      expect(spy).to.be.calledWithEql [name: 'trololo']
      expect(spy).to.be.calledWithEql [name: 'trolololo']

      store.context 'word'
      expect(spy).to.be.calledWithEql [name: 'word']
      expect(spy).to.have.callCount(3)

    it 'should not invoke the callback upon subsequent store#context calls that were also made before eachContext', ->
      store = racer.createStore()
      spy = sinon.spy()
      store.context 'word'
      store.eachContext spy

      expect(spy).to.be.calledWithEql [name: 'word']

      store.context 'word'
      expect(spy).to.have.callCount(1)
