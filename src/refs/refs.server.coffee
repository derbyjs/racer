uglify = require 'uglify-js'
{isProduction} = require '../util'

cbs = {}

module.exports =
  _onCreateRef: (method, from, to, key, get) ->
    args = if key then [method, from, to, key] else [method, from, to]
    @_refsToBundle.push [from, get, args]

  _onCreateFn: (path, inputs, callback) ->
    cb = callback.toString()
    if isProduction
      cb = cbs[cb] || (
        # Uglify can't parse a naked function. Executing it
        # allows Uglify to parse it properly
        uglified = uglify "(#{cb})()"
        cbs[cb] = uglified[1..-4]
      )

    fnsToBundle = @_fnsToBundle
    i = fnsToBundle.push(['fn', path, inputs..., cb]) - 1
    return -> delete fnsToBundle[i]
