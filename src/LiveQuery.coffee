{deepIndexOf, deepEqual} = require './util'
{lookup} = require './pathParser'

module.exports = LiveQuery = ->
  @_predicates = []
  return

LiveQuery::=
  from: (namespace) ->
    @_predicates.push (doc, channel) ->
      docNs = channel.substring 0, channel.indexOf '.'
      return namespace == docNs
    return this

  test: (doc, channel) ->
    # Over-write @test, so we compile and cache accumPredicate only once
    @test = compile @_predicates, @_paginatedCache, @_limit, @_skip, @_sort
    @test doc, channel

  byKey: (keyVal) ->
    @_predicates.push (doc, channel) ->
      [ns, id] = channel.split '.'
      return id == keyVal
    return this

  where: (@_currProp) ->
    return this

  equals: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      currVal = lookup currProp, doc
      if typeof currVal is 'object'
        return deepEqual currVal, val
      currVal == val
    return this

  notEquals: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      lookup(currProp, doc) != val
    return this

  gt: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      lookup(currProp, doc) > val
    return this

  gte: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      lookup(currProp, doc) >= val
    return this

  lt: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      lookup(currProp, doc) < val
    return this

  lte: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      lookup(currProp, doc) <= val
    return this

  within: (list) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      return -1 != list.indexOf lookup(currProp, doc)
    return this

  contains: (list) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      # TODO Handle flattened currProp - e.g., "phone.home"
      docList = lookup currProp, doc
      if docList is undefined
        return false if list.length
        return true # contains nothing
      for x in list
        if x.constructor == Object
          return false if -1 == deepIndexOf docList, x
        else
          return false if -1 == docList.indexOf x
      return true
    return this

  only: (paths...) ->
    if @_except
      throw new Error "You cannot specify both query(...).except(...) and query(...).only(...)"
    @_only ||= {}
    @_only[path] = 1 for path in paths
    return this

  except: (paths...) ->
    if @_only
      throw new Error "You cannot specify both query(...).except(...) and query(...).only(...)"
    @_except ||= {}
    @_except[path] = 1 for path in paths
    return this

  limit: (@_limit) ->
    @isPaginated = true
    cache = @_paginatedCache ||= []
    self = this
    return this

  skip: (skip) ->
    @isPaginated = true
    @_paginatedCache ||= []
    return this

  # sort('field1', 'asc', 'field2', 'desc', ...)
  sort: (params...) ->
    if @_sort && @_sort.length
      @_sort = @_sort.concat(params)
    else
      @_sort = params
    return this

evalToTrue = -> true

compile = (predicates, cache, limit, skip, sort) ->
  docFilter = compileDocFilter predicates
  if sort
    comparator = compileSortComparator sort

  return (doc, channel) ->
    unless isMatch = docFilter doc, channel
      rmFromCache doc, cache if cache
      return false
    return isMatch unless cache
    if cache.length < limit
      addToCache doc, cache, comparator
    else if cache.length == limit
      return maybeUpdateCache doc, cache, comparator
    return isMatch

compileDocFilter = (predicates) ->
  switch predicates.length
    when 0 then return evalToTrue
    when 1 then return predicates[0]
  return (doc, channel) ->
    return false if doc is undefined
    # AND all predicates together
    for pred in predicates
      return false unless pred doc, channel
    return true

addToCache = (doc, cache, query) ->
  # TODO

maybeUpdateCache = (doc, cache, comparator, skip) ->
  # TODO Leverage a binary search
  for x, i in cache
    switch comparator(doc, x)
      when -1, 0
        # If the document is already in the cache, do nothing
        return true if doc.id == x.id
        if i == 0 && skip > 0
          # We may have modified docA so that it is added to a
          # prev page, effectively displacing a docB in a prev
          # page, so docB ends up being unshifted into the curr page
          throw new Error 'Unimplemented'
        else
          cache.splice i, 0, doc
        break
  return {rmDoc: cache.pop()}

rmFromCache = (doc, cache) ->
  for {id}, i in cache
    return cache.splice(i, 1) if id == doc.id
  return

# Generates a comparator function that returns -1, 0, or 1
# if a < b, a == b, or a > b respectively, according to the
# ordering criteria defined by sortParams.
compileSortComparator = (sortParams) ->
  return (a, b) ->
    for path, i in sortParams by 2
      factor = switch sortParams[i+1]
        when 'asc' then 1
        when 'desc' then -1
        else throw new Error 'Must be "asc" or "desc"'
      aVal = lookup path, a
      bVal = lookup path, b
      # TODO Handle undefined aVal or bVal
      if aVal < bVal
        return -1 * factor
      else if aVal > bVal
        return factor
    return 0
