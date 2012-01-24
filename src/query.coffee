# 1. Register a query against an index
# 2. percolate::doc -> [query]

module.exports = query = (namespace) ->
  return (new Query()).from namespace

Query = ->
  @_calls = []
  return

Query::=
  isQuery: true

  serialize: -> @_calls

  # TODO Different order of method calls will create different
  #      hashes. Come up with a better way to id or equate
  #      queries.
  hash: ->
    hash = JSON.stringify @_calls
    return hash

  from: (@_namespace) ->
    @_calls.push ['from', [@_namespace]]
    @

query.deserialize = (calls, AdapterQuery = Query) ->
  q = new AdapterQuery
  for [method, args] in calls
    q[method] args...
  return q

for method in ['byKey', 'where', 'equals', 'notEquals',
  'within']
  do (method) ->
    Query::[method] = ->
      @_calls.push [method, Array::slice.call arguments]
      @
