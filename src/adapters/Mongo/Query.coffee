Promise = require '../../Promise'
module.exports = MongoQuery = ->
  @_conds = {}
  return

MongoQuery::=
  from: (@_namespace) ->
    return this

  byKey: (keyVal) ->
    @_conds._id = keyVal
    return this

  where: (@_currProp) ->
    return this

  equals: (val) ->
    @_conds[@_currProp] = val
    return this

  notEquals: (val) ->
    @_conds[@_currProp] = $ne: val
    return this

  gt: (val) ->
    @_conds[@_currProp] = $gt: val
    return this

  gte: (val) ->
    @_conds[@_currProp] = $gte: val
    return this

  lt: (val) ->
    @_conds[@_currProp] = $lt: val
    return this

  lte: (val) ->
    @_conds[@_currProp] = $lte: val
    return this

  within: (list) ->
    @_conds[@_currProp] = $in: list
    return this

  contains: (list) ->
    @_conds[@_currProp] = $all: list
    return this

  run: (mongoAdapter, callback) ->
    promise = new Promise bothback: callback
    mongoAdapter.find @_namespace, @_conds, {}, (err, found) ->
      promise.resolve err, found
    return promise
