pathParser = require '../pathParser'
empty = ->

module.exports =
  init: ->
    # Paths in the store that this model is subscribed to. These get set with
    # model.subscribe, and must be sent to the store upon connecting
    # Maps path -> 1
    @_storeSubs = {}

  setupSocket: (socket) ->
    self = this
    socket.on 'connect', ->
      # Establish subscriptions upon connecting and get any transactions
      # that may have been missed
      storeSubs = Object.keys self._storeSubs
      socket.emit 'sub', self._clientId, storeSubs, self._adapter.version, self._startId

  proto:
    subscribe: (_paths..., callback) ->
      # For subscribe(paths...)
      unless typeof callback is 'function'
        _paths.push callback
        callback = empty

      # TODO: Support all path wildcards, references, and functions
      paths = []
      storeSubs = @_storeSubs
      addPath = (path) ->
        for path in pathParser.expand path
          return if storeSubs[path]
          # These subscriptions are reestablished when the client connects
          storeSubs[path] = 1
          paths.push path

      for path in _paths
        if typeof path is 'object'
          for key, value of path
            root = pathParser.split(value)[0]
            @ref key, root
            addPath value
        else addPath path

      # Callback immediately if already subscribed
      return callback() unless paths.length
      @_addSub paths, callback

    unsubscribe: (paths..., callback) ->
      # For unsubscribe(paths...)
      unless typeof callback is 'function'
        paths.push callback
        callback = empty

      throw new Error 'Unimplemented: unsubscribe'

    # This method is over-written in Model.server
    _addSub: (paths, callback) ->
      self = this
      return callback() unless @connected
      @socket.emit 'subAdd', @_clientId, paths, (data, otData) ->
        self._initSubData data
        self._initSubOtData otData
        callback()

    _initSubData: (data) ->
      adapter = @_adapter
      setSubDatum adapter, datum  for datum in data
      return

    _initSubOtData: (data) ->
      fields = @otFields
      fields[path] = field for path, field of data
      return

setSubDatum = (adapter, [path, value, ver]) ->
  if path is ''
    if typeof value is 'object'
      for k, v of value
        adapter.set k, v, ver
      return
    throw 'Cannot subscribe to "' + path '"'

  return adapter.set path, value, ver
