{merge} = util = require './index'

util.speculative = module.exports =

  createObject: -> $spec: true

  createArray: ->
    obj = []
    obj.$spec = true
    return obj

  create: (proto) ->
    return proto  if proto.$spec

    if Array.isArray proto
      # TODO: Slicing is obviously going to be inefficient on large arrays, but
      # inheriting from arrays is very problematic. Eventually it would be good
      # to implement something faster in browsers that could support it. See:
      # http://perfectionkills.com/how-ecmascript-5-still-does-not-allow-to-subclass-an-array/#wrappers_prototype_chain_injection
      obj = proto.slice()
      obj.$spec = true
      return obj

    return Object.create proto, $spec: value: true

  clone: (proto) ->
    if Array.isArray proto
      obj = proto.slice()
      obj.$spec = true
      return obj

    return merge {}, proto

  isSpeculative: (obj) -> obj && obj.$spec

  identifier: '$spec' # Used in tests
