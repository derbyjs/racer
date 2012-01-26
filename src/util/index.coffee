module.exports =

  isServer: isServer = typeof window is 'undefined'
  isProduction: isServer && process.env.NODE_ENV is 'production'

  mergeAll: (to, froms...) ->
    for from in froms
      if from
        to[key] = value for key, value of from
    return to

  merge: (to, from) ->
    to[key] = value for key, value of from
    return to

  hasKeys: (obj, ignore) ->
    for key of obj
      continue if key is ignore
      return true
    return false

  bufferify: (methodName, {origFn, await}) ->
    buffer = null
    return ->
      self = this

      _arguments = arguments
      didFlush = false
      flush = ->
        didFlush = true

        # When we call flush, we no longer need to buffer,
        # so replace this method with the original method
        self[methodName] = origFn

        # Call the method with the first invocation arguments
        # if this is during the first call to methodName, 
        # await called flush immediately, and we therefore
        # have no buffered method calls.
        return unless buffer

        # Otherwise, invoke the buffered method calls
        for args in buffer
          origFn.apply self, args
        return
      # The first time we call methodName, run await
      await.call self, flush

      # If await decided we need no buffering and it called
      # flush, then call the original function with the
      # arguments to this first call to methodName
      if didFlush
        return self[methodName].apply self, _arguments

      # Otherwise, if we need to buffer calls to this method,
      # then, replace this method temporarily with code
      # that buffers the method calls until `flush` is called
      self[methodName] = ->
        buffer ||= []
        buffer.push arguments
      self[methodName].apply self, arguments

      return

  deepIndexOf: (arr, x) ->
    for mem in arr
      return i if deepEqual mem, x
    return -1

  # Ported to coffeescript from node.js assert.js
  deepEqual: deepEqual = (actual, expected) ->
      # 7.1. All identical values are equivalent, as determined by ==.
    return true if actual == expected

    if Buffer.isBuffer(actual) && Buffer.isBuffer(expected)
      return false if actual.length != expected.length

      for actualVal, i in actual
        return false if actualVal != expected[i]

      return true

    # 7.2. If the expected value is a Date object, the actual value is
    # equivalent if it is also a Date object that refers to the same time.
    if actual instanceof Date && expected instanceof Date
      return actual.getTime() == expected.getTime()

    # 7.3. Other pairs that do not both pass typeof value == 'object',
    # equivalence is determined by ==.
    if typeof actual != 'object' && typeof expected != 'object'
      return actual == expected

    # 7.4. For all other Object pairs, including Array objects, equivalence is
    # determined by having the same number of owned properties (as verified
    # with Object.prototype.hasOwnProperty.call), the same set of keys
    # (although not necessarily the same order), equivalent values for every
    # corresponding key, and an identical 'prototype' property. Note: this
    # accounts for both named and indexed properties on Arrays.
    return objEquiv actual, expected

  # Ported to coffeescript from node.js assert.js
  objEquiv: objEquiv = (a, b) ->
    if !a? && !b?
      # if isUndefinedOrNull(a) || isUndefinedOrNull(b)
      return false
    # an identical 'prototype' property.
    return false if a:: != b::
    #~~~I've managed to break Object.keys through screwy arguments passing.
    #   Converting to array solves the problem.
    if isArguments a
      return false unless isArguments b
      a = pSlice.call a
      b = pSlice.call b
      return deepEqual a, b
    try
      ka = Object.keys a
      kb = Object.keys b
    catch e #happens when one is a string literal and the other isn't
      return false
    # having the same number of owned properties (keys incorporates
    # hasOwnProperty)
    return false if ka.length != kb.length
    #the same set of keys (although not necessarily the same order),
    ka.sort()
    kb.sort()
    #~~~cheap key test
    i = ka.length
    while i--
      return false if (ka[i] != kb[i])
    #equivalent values for every corresponding key, and
    #~~~possibly expensive deep test
    i = ka.length
    while i--
      key = ka[i]
      return false unless deepEqual a[key], b[key]
    return true

  # TODO Test this
  deepCopy: deepCopy = (obj) ->
    if obj.constructor == Object
      ret = {}
      ret[k] = deepCopy v for k, v of obj
      return ret
    if Array.isArray obj
      ret = []
      ret.push deepCopy v for v in obj
      return ret
    return obj

