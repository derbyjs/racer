{isProduction} = require '../util'
{createFn} = refs = require './index'
uglify = require 'uglify-js'

refs.proto._createRef = (RefType, from, to, key) ->
  if @_at
    key = to
    to = from
    from = @_at
  model = @_root
  model._checkRefPath from, 'ref'
  {get, modelMethod} = new RefType model, from, to, key

  model.on 'bundle', ->
    return unless model._getRef(from) == get
    args = if key then [from, to, key] else [from, to]
    model._onLoad.push [modelMethod, args]
  model.set from, get
  return get

cbs = {}
refs.proto.fn = (inputs..., callback) ->
  path = if @_at then @_at else inputs.shift()
  model = @_root
  model._checkRefPath path, 'fn'
  listener = model.on 'bundle', ->
    cb = callback.toString()
    if isProduction
      cb = cbs[cb] || (
        # Uglify can't parse a naked function. Executing it
        # allows Uglify to parse it properly
        uglified = uglify "(#{cb})()"
        cbs[cb] = uglified.substr 1, uglified.length - 4
      )
    model._onLoad.push ['fn', [path, inputs..., cb]]
  return createFn model, path, inputs, callback, ->
    model.removeListener 'bundle', listener
