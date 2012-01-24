Promise = require '../../Promise'
module.exports = MongoQuery = ->
  @_conds = {}
  return

MongoQuery::=
  from: (@_namespace) -> @

  byKey: (keyVal) ->
    @_conds._id = keyVal
    @

  where: (@_currProp) -> @

  equals: (val) ->
    @_conds[@_currProp] = val
    @

  notEquals: (val) ->
    @_conds[@_currProp] = $ne: val
    @

  within: (list) ->
    @_conds[@_currProp] = $in: list

  run: (mongoAdapter, callback) ->
    promise = new Promise bothback: callback
    mongoAdapter.find @_namespace, @_conds, {}, (err, found) ->
      promise.resolve err, found
    return promise
