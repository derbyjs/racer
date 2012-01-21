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
      finalOverwrite = ->
        self[methodName] = origFn

      _arguments = arguments
      didFlush = false
      flush = ->
        didFlush = true

        # When we call flush, we no longer need to buffer,
        # so replace this method with the original method
        finalOverwrite()

        # Call the method with the first invocation arguments
        # if this is during the first call to methodName, 
        # await called flush immediately, and we therefore
        # have no buffered method calls.
        return self[methodName].apply self, _arguments unless buffer

        # Otherwise, invoke the buffered method calls
        for _arguments in buffer
          self[methodName].apply self, _arguments
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
