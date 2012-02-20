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
    subscribe: (targets..., callback) ->
      # For subscribe(paths...)
      unless typeof callback is 'function'
        targets.push callback
        callback = empty

      # TODO: Support all path wildcards, references, and functions
      channels = []
      storeSubs = @_storeSubs
      addPath = (path) ->
        for path in pathParser.expand path
          return if storeSubs[path]
          # These subscriptions are reestablished when the client connects
          storeSubs[path] = 1
          channels.push path

      querySubs = @_querySubs
      addQuery = (query) ->
        queryHash = query.hash()
        return if querySubs[queryHash]
        querySubs[queryHash] = 1
        channels.push query

      out = []
      for target in targets
        if target.isQuery
          addQuery target
        else
          root = pathParser.split(target)[0]
          out.push @at root, true
          addPath target

      # Callback immediately if already subscribed
      return callback out... unless channels.length
      @_addSub channels, -> callback out...

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
