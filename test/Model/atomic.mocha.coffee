# TODO: Add back once atomic transactions are implemented


# {expect} = require '../util'
# {Model, transaction} = require '../../lib/racer'
# {mockSocketEcho} = require '../util/model'

# Model::_commit = ->

# describe 'Model.atomic', ->

#   it 'Model::atomic should log gets', (done) ->
#     model = new Model
#     model.atomic (model) ->
#       model.get 'color'
#       expect(model.oplog().length).to.equal 1
#       op = model.oplog()[0]
#       expect(transaction.getMethod op).to.equal 'get'
#       done()

#   it 'AtomicModel::oplog should only contain the ops that *it* has done', (done) ->
#     model = new Model
#     model.set 'direction', 'west'
#     model.atomic (model) ->
#       model.get 'color'
#       expect(model.oplog().length).to.equal 1
#       op = model.oplog()[0]
#       expect(transaction.getMethod op).to.equal 'get'
#       expect(transaction.args op).to.eql ['color']
#       expect(model._txnQueue.length).to.equal 2
#       done()

#   it 'AtomicModel should keep around the transactions of its parents model', (done) ->
#     model = new Model
#     model.set 'direction', 'west'
#     model.atomic (model) ->
#       model.get 'color'
#       parentTxn = model._txns[model._txnQueue[0]]
#       expect(transaction.getMethod parentTxn).to.equal 'set'
#       expect(transaction.args parentTxn).to.eql ['direction', 'west']
#       done()

#   it 'AtomicModel sets should be reflected in the atomic model but not the parent model', (done) ->
#     model = new Model
#     model.set 'direction', 'west'
#     model.atomic (atomicModel) ->
#       atomicModel.set 'direction', 'north'
#       expect(model.get()).to.specEql direction: 'west'
#       expect(atomicModel.get()).to.specEql direction: 'north'
#       done()

#   it 'AtomicModel sets should be reflected in the parent speculative model after an implicit commit -- i.e., if no commit param was passed to model.atomic', (done) ->
#     model = new Model
#     model.set 'direction', 'west'
#     model.atomic (atomicModel) ->
#       atomicModel.set 'direction', 'north'
#     expect(model.get()).to.specEql direction: 'north'
#     done()

#   it 'if passed an explicit commit callback, AtomicModel should not reflect any of its ops in the parent speculative model until the commit callback is invoked inside the atomic block', (done) ->
#     model = new Model
#     model.set 'direction', 'west'
#     model.atomic (atomicModel, commit) ->
#       atomicModel.set 'direction', 'north'
#       setTimeout ->
#         commit()
#         done()
#       , 50
#     expect(model.get()).to.specEql direction: 'west'

#   it 'Model::atomic(lambda, callback) should invoke its callback once it receives a successful response for the txn from the upstream repo', (done) ->
#     [model, sockets] = mockSocketEcho 0
#     model.atomic (atomicModel) ->
#       atomicModel.set 'direction', 'north'
#     , (err, num) ->
#       expect(err).to.be.null()
#       sockets._disconnect()
#       done()

#   it 'Model::atomic(lambda, callback) should callback with an error if the commit failed at some point in an upstream repo', (done) ->
#     [model, sockets] = mockSocketEcho 0, txnErr: 'conflict'
#     model.atomic (atomicModel) ->
#       atomicModel.set 'direction', 'north'
#     , (err) ->
#       expect(err).to.equal 'conflict'
#       sockets._disconnect()
#       done()

#   it 'AtomicModel commits should not callback if it has not yet received the status of that commit', (done) ->
#     [model, sockets] = mockSocketEcho 0, unconnected: true
#     counter = 1
#     model.atomic (atomicModel) ->
#       atomicModel.set 'direction', 'north'
#     , (err) ->
#       counter++
#     setTimeout ->
#       expect(counter).to.equal 1
#       sockets._disconnect()
#       done()
#     , 50

#   it 'AtomicModel should commit *all* its ops to the parent models permanent, non-speculative data upon a successful transaction response from the parent repo', (done) ->
#     [model, sockets] = mockSocketEcho 0
#     model.atomic (atomicModel) ->
#       atomicModel.set 'color', 'green'
#       atomicModel.set 'volume', 'high'
#     , (err) ->
#       expect(err).to.be.null()
#       expect(model._adapter._data).to.specEql
#         world:
#           color: 'green'
#           volume: 'high'
#       sockets._disconnect()
#       done()

#   it 'a model should clean up its atomic model upon a successful commit of that atomic models transaction', (done) ->
#     [model, sockets] = mockSocketEcho 0
#     atomicModelId = null
#     model.atomic (atomicModel) ->
#       atomicModelId = atomicModel.id
#       atomicModel.set 'direction', 'north'
#     , (err) ->
#       expect(err).to.be.null()
#       expect(model._atomicModels[atomicModelId]).to.equal undefined
#       sockets._disconnect()
#       done()

#   it 'a model should not clean up its atomic model before the result of a commit (success or err) is known', (done) ->
#     [model, sockets] = mockSocketEcho 0
#     atomicModelId = null
#     model.atomic (atomicModel, commit) ->
#       atomicModelId = atomicModel.id
#       atomicModel.set 'direction', 'north'
#       setTimeout commit, 50
#     , (err) ->
#       expect(err).to.be.null()
#       expect(model._atomicModels[atomicModelId]).to.equal undefined
#       sockets._disconnect()
#       done()
#     expect(model._atomicModels[atomicModelId]).to.not.be.undefined

#   # TODO an atomic model should be able to retry itself when
#   # handling a commit err via the model.atomic callback

#   # TODO Pass the following tests

#   # TODO Tests involving refs and array refs

#   # TODO Tests for event emission proxying to parent models

#   # TODO Tests for nested, composable transactions

#   # TODO How to handle private paths?

#   # TODO AtomicModel commits should get passed to Store

#   # TODO AtomicModel commits should get passed to STM

#   # TODO a parent model should pass any speculative ops
#   # to its child atomic models

#   # TODO a parent model should pass any accepted ops to
#   # its child atomic models

#   # TODO a parent model should pass any aborted ops to
#   # its child atomic models
