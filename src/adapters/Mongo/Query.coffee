Promise = require '../../Promise'
module.exports = MongoQuery = ->
  @_conds = {}
  @_opts = {}
  return

MongoQuery::=
  from: (@_namespace) -> return this

  byKey: (keyVal) ->
    @_conds._id = keyVal
    return this

  where: (@_currProp) -> return this

  equals: (val) ->
    @_conds[@_currProp] = val
    return this

  notEquals: (val) ->
    @_conds[@_currProp] = $ne: val
    return this

  gt: (val) ->
    cond = @_conds[@_currProp] ||= {}
    cond.$gt = val
    return this

  gte: (val) ->
    cond = @_conds[@_currProp] ||= {}
    cond.$gte = val
    return this

  lt: (val) ->
    cond = @_conds[@_currProp] ||= {}
    cond.$lt = val
    return this

  lte: (val) ->
    cond = @_conds[@_currProp] ||= {}
    cond.$lte = val
    return this

  within: (list) ->
    @_conds[@_currProp] = $in: list
    return this

  contains: (list) ->
    @_conds[@_currProp] = $all: list
    return this

  only: (paths...) ->
    fields = @_opts.fields ||= {}
    fields[path] = 1 for path in paths
    return this

  except: (paths...) ->
    fields = @_opts.fields ||= {}
    fields[path] = 0 for path in paths
    return this

  skip: (skip) ->
    @_opts.skip = skip
    return this

  limit: (limit) ->
    @_opts.limit = limit
    return this

  # sort('field1', 'asc', 'field2', 'desc')
  sort: (params...) ->
    @_opts.sort = ([path, params[i+1]] for path, i in params by 2)
    return this

  run: (mongoAdapter, callback) ->
    promise = new Promise bothback: callback
    if @_opts.limit isnt undefined && @_opts.skip is undefined
      @skip 0
    mongoAdapter.find @_namespace, @_conds, @_opts, (err, found) ->
      promise.resolve err, found, xf
    return promise

xf = (doc) ->
  doc.id = doc._id
  delete doc._id
