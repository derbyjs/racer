# 1. Register a query against an index
# 2. percolate::doc -> [query]

module.exports = query = (namespace) ->
  q = new Query()
  q.from namespace if namespace
  return q

# We use ABBREVS for query hashing, so our hashes are more compressed
ABBREVS =
  equals: '$eq'
  notEquals: '$ne'
  gt: '$gt'
  gte: '$gte'
  lt: '$lt'
  lte: '$lte'
  within: '$wi'
  contains: '$cont'

Query = ->
  @_calls = []
  @_json = {}
  return

Query::=
  isQuery: true

  serialize: -> @_calls

  hash: ->
    sep = ':'
    groups = []
    calls = @_calls
    for [method, args] in calls
      switch method
        when 'from' then continue
        when 'where'
          group = {path: args[0]}
          pathCalls = group.calls = []
          groups.push group
        when 'equals', 'notEquals', 'gt', 'gte', 'lt', 'lte'
          pathCalls.push [ABBREVS[method], args]
        when 'within', 'contains'
          args[0].sort()
          pathCalls.push [ABBREVS[method], args]
        when 'only', 'except'
          selectHash = if method == 'only' then '$o' else '$e'
          selectHash += sep + path for path in args
        when 'sort'
          sortHash = '$s' + sep
          for path, i in args by 2
            sortHash += path + sep
            sortHash += switch args[i+1]
                          when 'asc'  then '^'
                          when 'desc' then 'v'
        when 'skip'
          skipHash = '$sk' + sep + args[0]
        when 'limit'
          limitHash = '$L' + sep + args[0]

    hash = @_namespace
    hash += sep + sortHash if sortHash
    hash += sep + selectHash if selectHash
    hash += sep + skipHash if skipHash
    hash += sep + limitHash if limitHash

    groups = groups.map (group) ->
      group.calls = group.calls.sort callsComparator
      group

    groups.sort (groupA, groupB) ->
      pathA = groupA.path
      pathB = groupB.path
      return -1 if pathA < pathB
      return 0 if pathA == pathB
      return 1

    for group in groups
      hash += sep + sep + group.path
      calls = group.calls
      for [method, args] in calls
        hash += sep + method
        for arg in args
          hash += sep + if typeof arg is 'object' then JSON.stringify arg else arg

    return hash

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

callsComparator = ([methodA], [methodB]) ->
  return -1 if methodA < methodB
  return 0 if methodA == methodB
  return 1
