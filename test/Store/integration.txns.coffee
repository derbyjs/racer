{expect} = require '../util'
transaction = require '../../lib/transaction'
{mockFullSetup} = require '../util/model'

# TODO More tests
module.exports = (plugins) ->
  describe 'Store transactions', ->
    it 'events should be emitted in remote subscribed models', (done) ->
      mockFullSetup @store, done, plugins, (modelA, modelB, done) ->
        modelA.on 'set', '_test.color', (value, previous, isLocal) ->
          expect(value).to.equal 'green'
          expect(previous).to.equal undefined
          expect(isLocal).to.equal false
          expect(modelA.get '_test.color').to.equal 'green'
          done()
        modelB.set '_test.color', 'green'

  describe 'a quickly reconnected client', ->
    it 'should receive transactions buffered by the store while it was offline', (done) ->
      store = @store
      oldVer = null
      mockFullSetup store, done, plugins,
        preBundle: (model) ->
          model.set '_test.color', 'blue'
        postBundle: (model) ->
          path = model.dereference('_test') + '.color'
          txn = transaction.create
            id: '1.0', method: 'set', args: [path, 'green'], ver: ++model._memory.version
          store.publish path, 'txn', txn
        preConnect: (model) ->
          expect(model.get('_test.color')).to.equal 'blue'
          oldVer = model._memory.version
        postConnect: (model, done) ->
          process.nextTick -> process.nextTick ->
            expect(model.get('_test.color')).to.equal 'green'
            expect(model._memory.version).to.equal oldVer+1
            done()
