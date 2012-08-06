Async = require './Async'
Memory = require '../Memory'

# TODO: Perhaps this should be a macro. Needs DRYing

module.exports =
  type: 'Model'

  static:
    ACCESSOR: ACCESSOR = 'accessor'
    BASIC_MUTATOR: BASIC_MUTATOR = 'mutator,basicMutator'
    COMPOUND_MUTATOR: COMPOUND_MUTATOR = 'mutator,compoundMutator'
    ARRAY_MUTATOR: ARRAY_MUTATOR = 'mutator,arrayMutator'

  events:
    init: (model) ->
      # Memory instance for use in building multiple path objects in async get
      memory = new Memory

      model.async = new Async
        model: model

        nextTxnId: ->
          model._nextTxnId()

        get: (path, callback) ->
          model._upstreamData [path], (err, data) ->
            return callback err if err

            # Return undefined if no data matched
            return callback() unless (items = data.data) && (len = items.length)

            # Return the value for a single matching item on the same path
            if len is 1 && (item = items[0]) && item[0] == path
              return callback null, item[1]

            # Return a multiple path object, such as the result of a query
            for [subpath, value] in items
              memory.set subpath, value, -1
            out = memory.get path
            memory.flush()
            callback null, out

        commit: (txn, callback) ->
          model._asyncCommit txn, callback

  proto:
    get:
      type: ACCESSOR
      fn: (path) ->
        if at = @_at
          path = if path then at + '.' + path else at
        @_memory.get path, @_specModel()

    set:
      type: BASIC_MUTATOR
      fn: (path, value, callback) ->
        if at = @_at
          len = arguments.length
          path = if len is 1 || len is 2 && typeof value is 'function'
            callback = value
            value = path
            at
          else
            at + '.' + path
        return @_sendToMiddleware 'set', [path, value], callback

    del:
      type: BASIC_MUTATOR
      fn: (path, callback) ->
        if at = @_at
          path = if typeof path is 'string'
            at + '.' + path
          else
            callback = path
            at
        return @_sendToMiddleware 'del', [path], callback

    add:
      type: COMPOUND_MUTATOR
      fn: (path, value, callback) ->
        len = arguments.length
        if @_at && len is 1 || len is 2 && typeof value is 'function'
          callback = value
          value = path
          if typeof value isnt 'object'
            throw 'model.add() requires an object argument'
          path = id = value.id ||= @id()
        else
          value ||= {}
          if typeof value isnt 'object'
            throw 'model.add() requires an object argument'
          id = value.id ||= @id()
          path = path + '.' + id

        if callback
          @set path, value, (err) -> callback err, id
        else
          @set path, value
        return id

    setNull:
      type: COMPOUND_MUTATOR
      fn: (path, value, callback) ->
        len = arguments.length
        obj = if @_at && len is 1 || len is 2 && typeof value is 'function'
          @get()
        else
          @get path
        return obj  if obj?

        if len is 1
          return @set path
        else if len is 2
          return @set path, value
        else
          return @set path, value, callback

    incr:
      type: COMPOUND_MUTATOR
      fn: (path, byNum, callback) ->
        if typeof path isnt 'string'
          callback = byNum
          byNum = path
          path = ''

        if typeof byNum is 'function'
          callback = byNum
          byNum = 1
        else if typeof byNum isnt 'number'
          byNum = 1
        value = (@get(path) || 0) + byNum

        if path
          @set path, value, callback
          return value

        if callback
          @set value, callback
        else
          @set value
        return value

    push:
      type: ARRAY_MUTATOR
      insertArgs: 1
      fn: (args...) ->
        if at = @_at
          if typeof (path = args[0]) is 'string' &&
              (current = @get()) && !Array.isArray(current)
            args[0] = at + '.' + path
          else
            args.unshift at

        if typeof args[args.length - 1] is 'function'
          callback = args.pop()

        return @_sendToMiddleware 'push', args, callback

    unshift:
      type: ARRAY_MUTATOR
      insertArgs: 1
      fn: (args...) ->
        if at = @_at
          if typeof (path = args[0]) is 'string' &&
              (current = @get()) && !Array.isArray(current)
            args[0] = at + '.' + path
          else
            args.unshift at

        if typeof args[args.length - 1] is 'function'
          callback = args.pop()
        return @_sendToMiddleware 'unshift', args, callback

    insert:
      type: ARRAY_MUTATOR
      indexArgs: [1]
      insertArgs: 2
      fn: (args...) ->
        if at = @_at
          # isNaN will be false for index values in a string like '3'
          if typeof (path = args[0]) is 'string' && isNaN path
            args[0] = at + '.' + path
          else
            args.unshift at
        if match = /^(.*)\.(\d+)$/.exec args[0]
          # Use the index from the path if it ends in an index segment
          args[0] = match[1]
          args.splice 1, 0, match[2]

        if typeof args[args.length - 1] is 'function'
          callback = args.pop()
        return @_sendToMiddleware 'insert', args, callback

    pop:
      type: ARRAY_MUTATOR
      fn: (path, callback) ->
        if at = @_at
          path = if typeof path is 'string'
            at + '.' + path
          else
            callback = path
            at
        return @_sendToMiddleware 'pop', [path], callback

    shift:
      type: ARRAY_MUTATOR
      fn: (path, callback) ->
        if at = @_at
          path = if typeof path is 'string'
            at + '.' + path
          else
            callback = path
            at
        return @_sendToMiddleware 'shift', [path], callback

    remove:
      type: ARRAY_MUTATOR
      indexArgs: [1]
      fn: (path, start, howMany, callback) ->
        if at = @_at
          # isNaN will be false for index values in a string like '3'
          path = if typeof path is 'string' && isNaN path
            at + '.' + path
          else
            callback = howMany
            howMany = start
            start = path
            at
        if match = /^(.*)\.(\d+)$/.exec path
          # Use the index from the path if it ends in an index segment
          callback = howMany
          howMany = start
          start = match[2]
          path = match[1]

        if typeof howMany isnt 'number'
          callback = howMany
          howMany = 1
        return @_sendToMiddleware 'remove', [path, start, howMany], callback

    move:
      type: ARRAY_MUTATOR
      indexArgs: [1, 2]
      fn: (path, from, to, howMany, callback) ->
        if at = @_at
          # isNaN will be false for index values in a string like '3'
          path = if typeof path is 'string' && isNaN path
            at + '.' + path
          else
            callback = howMany
            howMany = to
            to = from
            from = path
            at
        if match = /^(.*)\.(\d+)$/.exec path
          # Use the index from the path if it ends in an index segment
          callback = howMany
          howMany = to
          to = from
          from = match[2]
          path = match[1]

        if typeof howMany isnt 'number'
          callback = howMany
          howMany = 1
        return @_sendToMiddleware 'move', [path, from, to, howMany], callback
