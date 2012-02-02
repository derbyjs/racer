# 1. Register a query against an index
# 2. percolate::doc -> [query]

module.exports = query = (namespace) ->
  q = new Query()
  q.from namespace if namespace
  return q

Query = ->
  @_calls = []
  return

Query::=
  isQuery: true

  serialize: -> @_calls

  # TODO Different order of method calls will create different
  #      hashes. Come up with a better way to id or equate
  #      queries.
  hash: -> JSON.stringify @_calls

  from: (@_namespace) ->
    @_calls.push ['from', [@_namespace]]
    return this

  skip: (args...) ->
    @isPaginated = true
    @_calls.push ['skip', args]
    return this

  limit: (args...) ->
    @isPaginated = true
    @_calls.push ['limit', args]
    return this

query.deserialize = (calls, AdapterQuery = Query) ->
  q = new AdapterQuery
  for [method, args] in calls
    q[method] args...
  q.serialize = -> calls
  return q

for method in ['byKey', 'where', 'equals', 'notEquals',
  'gt', 'gte', 'lt', 'lte', 'within', 'contains',
  'only', 'except', 'sort']
  do (method) ->
    Query::[method] = (args...) ->
      @_calls.push [method, args]
      return this
