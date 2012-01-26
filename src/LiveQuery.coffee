module.exports = LiveQuery = ->
  @_predicates = []
  return

LiveQuery::=
  from: (namespace) ->
    @_predicates.push (doc, channel) ->
      docNs = channel.substring 0, channel.indexOf '.'
      return namespace == docNs
    @

  test: (doc, channel) ->
    accumPredicate = @_compile()
    # Over-write @test, so we compile and cache accumPredicate only once
    @test = (doc, channel) ->
      accumPredicate doc, channel
    @test doc, channel

  _compile: ->
    predicates = @_predicates
    switch predicates.length
      when 0 then return evalToTrue
      when 1 then return predicates[0]
    return (doc, channel) ->
      # AND all predicates together
      for pred in predicates
        return false unless pred doc, channel
      return true

  byKey: (keyVal) ->
    @_predicates.push (doc, channel) ->
      [ns, id] = channel.split '.'
      return id == keyVal
    @

  where: (@_currProp) -> @

  equals: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      doc[currProp] == val
    @

  notEquals: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      doc[currProp] != val
    @

  gt: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      doc[currProp] > val
    @

  gte: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      doc[currProp] >= val
    @

  lt: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      doc[currProp] < val
    @

  lte: (val) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      doc[currProp] <= val
    @

  within: (list) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      return -1 != list.indexOf doc[currProp]
    @

  contains: (list) ->
    currProp = @_currProp
    @_predicates.push (doc) ->
      # TODO Handle flattened currProp - e.g., "phone.home"
      docList = doc[currProp]
      for x in list
        if x.constructor == Object
          return false if -1 == deepIndexOf docList, x
        else
          return false if -1 == docList.indexOf x
      return true
    @

evalToTrue = -> true
