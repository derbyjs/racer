SpecObject = -> return
SpecObject:: =
  $spec: true

module.exports =

  SpecObject: SpecObject

  createObject: ->
    new SpecObject

  createArray: ->
    arr = []
    arr.$spec = true
    return arr

  create: (proto) ->
    if Array.isArray proto
      # TODO: Slicing is obviously going to be inefficient on large arrays, but inheriting
      # from arrays is very problematic. Eventually it would be good to implement something
      # faster in browsers that could support it, such as:
      # http://perfectionkills.com/how-ecmascript-5-still-does-not-allow-to-subclass-an-array/#wrappers_prototype_chain_injection
      arr = proto.slice()
      arr.$spec = true
      return arr

    obj = Object.create proto
    obj.$spec = true
    return obj

  isSpeculative: (obj) -> '$spec' of obj

  identifier: '$spec'
