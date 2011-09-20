Model = require 'Model'
should = require 'should'
util = require './util'
transaction = require 'transaction'
wrapTest = util.wrapTest

{mockSocketModel, mockSocketModels} = require './util/model'

module.exports =
  'Model::atomic should log gets @single': wrapTest (done) ->
    model = new Model
    model.atomic (model) ->
      model.get 'color'
      model.oplog().length.should.equal 1
      op = model.oplog()[0]
      transaction.method(op).should.equal 'get'
      done()

  '''AtomicModel::oplog should only contain the ops that
  *it* has done @single''': wrapTest (done) ->
    model = new Model
    model.set 'direction', 'west'
    model.atomic (model) ->
      model.get 'color'
      model.oplog().length.should.equal 1
      op = model.oplog()[0]
      transaction.method(op).should.equal 'get'
      transaction.args(op).should.eql ['color']
      model._txnQueue.length.should.equal 2
      done()

  '''AtomicModel should keep around the transactions of
  its parent's model @single''': wrapTest (done) ->
    model = new Model
    model.set 'direction', 'west'
    model.atomic (model) ->
      model.get 'color'
      parentTxn = model._txns[model._txnQueue[0]]
      transaction.method(parentTxn).should.equal 'set'
      transaction.args(parentTxn).should.eql ['direction', 'west']
      done()

  '''AtomicModel sets should be reflected in the atomic
  model but not the parent model @single''': wrapTest (done) ->
    model = new Model
    model.set 'direction', 'west'
    model.atomic (atomicModel) ->
      atomicModel.set 'direction', 'north'
      model.get().should.specEql direction: 'west'
      atomicModel.get().should.specEql direction: 'north'
      done()

  '''AtomicModel sets should be reflected in the parent
  model after an implicit commit @single''': wrapTest (done) ->
    model = new Model
    model.set 'direction', 'west'
    model.atomic (atomicModel) ->
      atomicModel.set 'direction', 'north'
    model.get().should.specEql direction: 'north'
    done()

  '''an atomic transaction should commit all its ops
  to the parent model if no commit param was passed to
  model.atomic''': -> #TODO

  '''a parent model should pass any speculative ops
  to its child atomic models''': -> # TODO

  '''a parent model should pass any accepted ops to
  its child atomic models''': -> #TODO

  '''a parent model should pass any aborted ops to
  its child atomic models''': -> #TODO

#  'an atomic transaction should commit all its ops': wrapTest (done)->
#    model = new Model
#    model.atomic (model) ->
#      model.set 'color', 'green'
#      model.set 'volume', 'high'
#    , (err) ->
#      err.should.be.null
#      done()
#  , 1
#
#  'a failed atomic transaction should not have any of its ops persisted': wrapTest (done)->
#    [socket, modelA, modelB] = mockSocketModels 'modelA', 'modelB'
#    modelA.atomic (model) ->
#      model.set 'color', 'green'
#      model.set 'volume', 'high'
#    , (err) ->
#      err.should.equal 'conflict'
#      done()
#  , 1
