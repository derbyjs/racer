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

#  'AtomicModel::oplog should only contain the ops that *it* has done': ->
#    # TODO
#
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
