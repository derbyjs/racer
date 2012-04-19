util = require './index'

util.async = module.exports =
  finishAfter: finishAfter = (count, callback) ->
    callback ||= (err) ->
      throw err if err
    return callback unless count
    err = null
    return (_err) ->
      err ||= _err
      --count || callback err

  forEach: (items, fn, done) ->
    finish = finishAfter items.length, done
    for item in items
      fn item, finish
    return

  bufferifyMethods: (Klass, methodNames, {await}) ->
    fns = {}
    buffer = null
    methodNames.forEach (methodName) ->
      fns[methodName] = Klass::[methodName]
      Klass::[methodName] = ->
        _arguments = arguments
        didFlush = false

        flush = =>
          didFlush = true

          # When we call flush, we no longer need to buffer,
          # so replace each method with the original method
          methodNames.forEach (methodName) =>
            @[methodName] = fns[methodName]
          delete await.alredyCalled

          # Call the method with the first invocation arguments
          # if this is during the first call to methodName,
          # await called flush immediately, and we therefore
          # have no buffered method calls.
          return unless buffer

          # Otherwise, invoke the buffered method calls
          for args in buffer
            fns[methodName].apply this, args
          buffer = null
          return

        # The first time we call methodName, run await
        return if await.alredyCalled
        await.alredyCalled = true
        await.call this, flush

        # If await decided we need no buffering and it called
        # flush, then call the original function with the
        # arguments to this first call to methodName
        if didFlush
          return @[methodName].apply this, _arguments

        # Otherwise, if we need to buffer calls to this method,
        # then, replace this method temporarily with code
        # that buffers the method calls until `flush` is called
        @[methodName] = ->
          buffer ||= []
          buffer.push arguments
        @[methodName].apply this, arguments

        return

    bufferify: (methodName, {fn, await}) ->
      buffer = null
      return ->
        _arguments = arguments
        didFlush = false

        flush = =>
          didFlush = true

          # When we call flush, we no longer need to buffer,
          # so replace this method with the original method
          @[methodName] = fn

          # Call the method with the first invocation arguments
          # if this is during the first call to methodName, 
          # await called flush immediately, and we therefore
          # have no buffered method calls.
          return unless buffer

          # Otherwise, invoke the buffered method calls
          for args in buffer
            fn.apply this, args
          buffer = null
          return
        # The first time we call methodName, run await
        await.call this, flush

        # If await decided we need no buffering and it called
        # flush, then call the original function with the
        # arguments to this first call to methodName
        if didFlush
          return @[methodName].apply this, _arguments

        # Otherwise, if we need to buffer calls to this method,
        # then, replace this method temporarily with code
        # that buffers the method calls until `flush` is called
        @[methodName] = ->
          buffer ||= []
          buffer.push arguments
        @[methodName].apply this, arguments

        return
