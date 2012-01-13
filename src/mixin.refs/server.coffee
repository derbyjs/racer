{isProduction} = require '../util'
{createFn} = refs = require './index'
uglify = require 'uglify-js'

refs.proto._createRef = (RefType, from, to, key) ->
    @_checkRefPath from
    {get, modelMethod} = new RefType this, from, to, key

    model = this
    @on 'bundle', ->
      if model.getRef(from) == get
        args = if key then [from, to, key] else [from, to]
        model._onLoad.push [modelMethod, args]
    @set from, get
    return get

cbs = {}
refs.proto.fn = (path, inputs..., callback) ->
  @_checkRefPath path
  model = this
  @on 'bundle', ->
    #TODO check that fn still exists
    cb = callback.toString()
    if isProduction
      cb = cbs[cb] || (
        # Uglify can't parse a naked function. Executing it
        # allows Uglify to parse it properly
        uglified = uglify "(#{cb})()"
        cbs[cb] = uglified.substr(1, uglified.length - 4)
      )
    model._onLoad.push ['fn', [path, inputs..., cb]]
  return createFn this, path, inputs, callback
