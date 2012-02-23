pathParser = require '../pathParser'
empty = ->

module.exports =
  init: ->
    # Paths in the store that this model is subscribed to. These get set with
    # model.subscribe, and must be sent to the store upon connecting
    # Maps path -> 1
    @_storeSubs = {}
    @_querySubs = {}

  setupSocket: (socket) ->
    self = this
    socket.on 'connect', ->
      # Establish subscriptions upon connecting and get any transactions
      # that may have been missed
      storeSubs = Object.keys self._storeSubs
      socket.emit 'sub', self._clientId, storeSubs, self._adapter.version, self._startId

  proto:
    subscribe: (targets...) ->
      # For subscribe(targets..., callback)
      last = targets[targets.length - 1]
      callback = if typeof last is 'function' then targets.pop() else empty

      # These subscriptions are reestablished when the client connects
      querySubs = @_querySubs
      storeSubs = @_storeSubs

      channels = []
      addQuery = (query) ->
        queryHash = query.hash()
        return if querySubs[queryHash]
        querySubs[queryHash] = 1
        channels.push query
      addPath = (path) ->
        for path in pathParser.expand path
          continue if storeSubs[path]
          storeSubs[path] = 1
          channels.push path

      out = []
      for target in targets
        if target.isQuery
          addQuery target
          root = target.namespace
        else
          target = target._at  if target._at
          addPath target
          root = pathParser.split(target)[0]
        out.push @at root, true

      # Callback immediately if already subscribed
      return callback out... unless channels.length

      self = this
      @_addSub channels, (err, data, otData) ->
        self._initSubData data
        self._initSubOtData otData
        for channel in channels
          if channel.isQuery
            self.liveQueries[channel.hash()] = channel.serialize()
        callback out...

    unsubscribe: (paths..., callback) ->
      # For unsubscribe(paths...)
      unless typeof callback is 'function'
        paths.push callback
        callback = empty

      throw new Error 'Unimplemented: unsubscribe'

    # This method is over-written in Model.server
    _addSub: (paths, callback) ->
      return callback() unless @connected
      @socket.emit 'subAdd', @_clientId, paths, callback

    _initSubData: (data) ->
      adapter = @_adapter
      for [path, value, ver] in data
        if path is ''
          if typeof value is 'object'
            for k, v of value
              adapter.set k, v, ver
            continue
          throw 'Cannot subscribe to "' + path '"'
        adapter.set path, value, ver
      return

    _initSubOtData: (data) ->
      fields = @otFields
      fields[path] = field for path, field of data
      return
