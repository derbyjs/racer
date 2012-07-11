{expect} = require '../util'
racer = require '../../lib/racer'
sinon = require 'sinon'

describe 'Store', ->
  describe '#context', ->
    it 'should default store#currContext to "default" before the block', ->
      store = racer.createStore()
      expect(store.currContext).to.have.property('name', 'default')

    it 'should set store#currContext inside the block', ->
      store = racer.createStore()
      store.context 'inception', ->
        expect(store.currContext).to.have.property('name', 'inception')

    it 'should set store#currContext to "default" after the block', ->
      store = racer.createStore()
      expect(store.currContext).to.have.property('name', 'default')

  describe '#eachContext(callback)', ->
    it 'should pass every context we have defined to a callback', ->
      store = racer.createStore()
      ctx = store.context 'huey', ->
      cleanContext ctx

      ctx = store.context 'duey', ->
      cleanContext ctx

      ctx = store.context 'luey', ->
      cleanContext ctx

      spy = sinon.spy()
      store.eachContext spy

      expect(spy).to.be.calledWithEql [name: 'huey']
      expect(spy).to.be.calledWithEql [name: 'duey']
      expect(spy).to.be.calledWithEql [name: 'luey']

      expect(spy).to.have.callCount(4) # huey, duey, luey, default

    it 'should invoke the callback upon subsequent store#context calls', ->
      store = racer.createStore()
      ctx = store.context 'trolololo'
      cleanContext ctx
      ctx = store.context 'trololo'
      cleanContext ctx

      spy = sinon.spy()
      store.eachContext spy

      expect(spy).to.be.calledWithEql [name: 'trololo']
      expect(spy).to.be.calledWithEql [name: 'trolololo']

      ctx = store.context 'word'
      cleanContext ctx
      expect(spy).to.be.calledWithEql [name: 'word']
      expect(spy).to.have.callCount(4) # trololo, trolololo, word, default

    it 'should not invoke the callback upon subsequent store#context calls that were also made before eachContext', ->
      store = racer.createStore()

      ctx = store.context 'word'
      cleanContext ctx

      spy = sinon.spy()
      store.eachContext spy

      expect(spy).to.be.calledWithEql [name: 'word']

      ctx = store.context 'word'
      cleanContext ctx
      expect(spy).to.have.callCount(2) # word, default


cleanContext = (ctx) ->
  ['guardReadPath', 'guardQuery', 'guardWrite'].forEach (ignore) ->
    delete ctx[ignore]
