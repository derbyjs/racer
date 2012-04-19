{mergeAll, deepCopy} = require '../../util'
{lookup, assign} = require '../../path'
Promise = require '../../util/Promise'
LiveQuery = require '../../pubSub/LiveQuery'

module.exports = MemoryQuery = (query) ->
  @_opts = {}
  LiveQuery.call this, query
  return

mergeAll MemoryQuery::, LiveQuery::,
  only: (paths...) ->
    @_selectType = 'only'
    fields = @_opts.fields ||= {}
    fields[path] = 1 for path in paths
    return this

  except: (paths...) ->
    @_selectType = 'except'
    fields = @_opts.fields ||= {}
    fields[path] = 0 for path in paths
    return this

  skip: (skip) ->
    @_opts.skip = skip
    return this

  limit: (limit) ->
    @_opts.limit = limit
    return this

  run: (memoryAdapter, callback) ->
    promise = (new Promise).on callback
    matches = memoryAdapter.filter (doc, namespacePlusId) =>
      @testWithoutPaging doc, namespacePlusId

    matches = (deepCopy doc for doc in matches)

    if @_comparator
      matches.sort @_comparator

    {skip, limit, fields} = @_opts
    if limit isnt undefined
      skip = 0 if skip is undefined
      matches = matches.slice(skip, skip + limit)

    if selectType = @_selectType
      for doc, i in matches
        projectedDoc = {}
        if selectType is 'only'
          for field of fields
            assign projectedDoc, field, lookup(field, doc)
          assign projectedDoc, 'id', lookup('id', doc)
        else if selectType is 'except'
          assignExcept projectedDoc, doc, fields
        else
          return promise.resolve new Error
        matches[i] = projectedDoc

    return promise.resolve null, matches

# TODO Move this into a ./util file
assignExcept = (to, from, exceptions) ->
  return if from is undefined
  for key, val of from
    continue if key of exceptions

    nextExceptions = []
    hasNextExceptions = false
    for except of exceptions
      periodPos = except.indexOf '.'
      if except[0...periodPos] == key
        hasNextExceptions = true
        nextExceptions[excep[0..periodPos]] = 0

    if hasNextExceptions
      nextTo = to[key] = if Array.isArray from[key] then [] else {}
      assignExcept nextTo, from[key], nextExceptions
    else
      if Array.isArray from
        key = parseInt key, 10
      to[key] = from[key]
  return to
