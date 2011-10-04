pathParser = require '../pathParser'

module.exports =
  setupSocket: (socket) ->
    self = this
    {_adapter} = self = this
    storeSubs = Object.keys self._storeSubs
    socket.on 'connect', ->
      # Establish subscriptions upon connecting and get any transactions
      # that may have been missed
      socket.emit 'sub', self._clientId, storeSubs, _adapter.ver, self._startId

  proto:
    subscribe: (_paths..., callback) ->
      # For subscribe(paths...)
      unless typeof callback is 'function'
        _paths.push callback
        callback = -> # TODO Do not generate a fn. Set to null

      # TODO: Support all path wildcards, references, and functions
      paths = []
      for path in _paths
        if typeof path is 'object'
          for key, value of path
            root = pathParser.splitPattern(value)[0]
            @set key, @ref root
            paths.push value
          continue
        unless @_storeSubs[path]
          # These subscriptions are reestablished when the client connects
          @_storeSubs[path] = 1
          paths.push path

      return callback() unless paths.length
      @_addSub paths, callback

    unsubscribe: (paths..., callback) ->
      # For unsubscribe(paths...)
      unless typeof callback is 'function'
        paths.push callback
        callback = ->

      throw new Error 'Unimplemented: unsubscribe'

    _addSub: (paths, callback) ->
      self = this
      return callback() unless @connected
      @socket.emit 'subAdd', @_clientId, paths, (data) ->
        self._initSubData data
        callback()

    _initSubData: (data) ->
      adapter = @_adapter
      setSubDatum adapter, datum  for datum in data
      return

setSubDatum = (adapter, [root, remainder, value, ver]) ->
  if root is ''
    if typeof value is 'object'
      for k, v of value
        adapter.set k, v, ver
      return
    throw 'Cannot subscribe to "' + root + remainder + '"'

  return adapter.set root, value, ver
