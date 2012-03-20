uglify = require 'uglify-js'
{isProduction} = require '../util'

cbs = {}

module.exports =
  _onCreateRef: (method, from, to, key, get) ->
    args = [method, from, to]
    args.push key if key
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
    len = fnsToBundle.push ['fn', path, inputs..., cb]
    return -> delete fnsToBundle[len-1]
