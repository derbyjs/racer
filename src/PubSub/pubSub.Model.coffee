transaction = require '../transaction'
{expand: expandPath, split: splitPath} = require '../path'
LiveQuery = require './LiveQuery'
{deserialize} = Query = require './Query'
empty = ->

module.exports =
  type: 'Model'

  events:
    init: (model) ->
      # Paths in the store that this model is subscribed to. These get set with
      # model.subscribe, and must be sent to the store upon connecting
      model._pathSubs = {}     # maps path -> 1
      model._querySubs = {}    # maps hash -> query
      model._liveQueries = {}  # maps hash -> liveQuery

    bundle: (model) ->
      querySubs = []
      for hash, query of model._querySubs
        querySubs.push query
      model._onLoad.push ['_loadSubs', model._pathSubs, querySubs]

    socket: (model, socket) ->
      socket.on 'connect', ->
        # Establish subscriptions upon connecting and get any transactions
        # that may have been missed
        subs = Object.keys model._pathSubs
        for hash, query of model._querySubs
          subs.push query
        socket.emit 'sub', model._clientId, subs, model._memory.version, model._startId

      addRemoteTxn = model._addRemoteTxn

      socket.on 'addDoc', ({doc, ns, ver}, num) ->
        data = memory._data.world[ns] ||= {}
        # If the doc is already in the model, don't add it
        if memory._data.world[ns][doc.id]
          # But add a null transaction anyway, so that `txnApplier`
          # doesn't hang because it never sees `num`
          return addRemoteTxn null, num

        txn = transaction.create base: ver, id: null, method: 'set', args: ["#{ns}.#{doc.id}", doc]
        addRemoteTxn txn, num
        model.emit 'addDoc', "#{ns}.#{doc.id}", doc

      socket.on 'rmDoc', ({doc, ns, hash, id, ver}, num) ->
        # TODO Optimize this by sending + using only ns.id
        for key, query of model._liveQueries
          # Remove the doc from here if any other queries --
          # besides the one that triggered the rmDoc -- match the doc
          if hash != key && query.test doc, "#{ns}.#{id}"
            return addRemoteTxn null, num

        txn = transaction.create base: ver, id: null, method: 'del', args: ["#{ns}.#{id}"]
        addRemoteTxn txn, num
        model.emit 'rmDoc', ns + '.' + id, doc

  proto:
    _loadSubs: (@_pathSubs, _querySubs) ->
      querySubs = @_querySubs
      liveQueries = @_liveQueries
      for item in _querySubs
        query = deserialize item
        hash = query.hash()
        querySubs[hash] = query
        liveQueries[hash] = deserialize item, LiveQuery

    query: (namespace) -> new Query namespace

    fetch: (targets...) ->
      # For fetch(targets..., callback)
      last = targets[targets.length - 1]
      callback = if typeof last is 'function' then targets.pop() else empty

      newTargets = []
      out = []
      for target in targets

        if target.isQuery
          root = target.namespace
          newTargets.push target

        else
          target = target._at  if target._at
          root = splitPath(target)[0]
          for path in expandPath target
            newTargets.push path

        out.push @at root, true

      @_fetch newTargets, (err, data, otData) =>
        @_initSubData data
        @_initSubOtData otData
        callback out...

    subscribe: (targets...) ->
      # For subscribe(targets..., callback)
      last = targets[targets.length - 1]
      callback = if typeof last is 'function' then targets.pop() else empty

      pathSubs = @_pathSubs
      querySubs = @_querySubs
      liveQueries = @_liveQueries

      newTargets = []
      out = []
      for target in targets

        if target.isQuery
          root = target.namespace
          hash = target.hash()
          unless querySubs[hash]
            querySubs[hash] = target
            liveQueries[hash] = deserialize target.serialize(), LiveQuery
            newTargets.push target

        else
          target = target._at  if target._at
          root = splitPath(target)[0]
          for path in expandPath target
            continue if pathSubs[path]
            pathSubs[path] = 1
            newTargets.push path

        out.push @at root, true

      # Callback immediately if already subscribed to everything
      return callback out... unless newTargets.length

      @_subAdd newTargets, (err, data, otData) =>
        @_initSubData data
        @_initSubOtData otData
        callback out...

    unsubscribe: (targets...) ->
      # For unsubscribe(targets..., callback)
      last = targets[targets.length - 1]
      callback = if typeof last is 'function' then targets.pop() else empty

      pathSubs = @_pathSubs
      querySubs = @_querySubs
      liveQueries = @_liveQueries

      newTargets = []
      for target in targets

        if target.isQuery
          hash = target.hash()
          if querySubs[hash]
            delete querySubs[hash]
            delete liveQueries[hash]
            newTargets.push target

        else
          for path in expandPath target
            continue unless pathSubs[path]
            delete pathSubs[path]
            newTargets.push path

      # Callback immediately if already unsubscribed from everything
      return callback() unless newTargets.length

      @_subRemove newTargets, callback

    _initSubData: (data) ->
      memory = @_memory
      for [path, value, ver] in data
        if path is ''
          if typeof value is 'object'
            for k, v of value
              memory.set k, v, ver
            continue
          throw 'Cannot subscribe to "' + path '"'
        memory.set path, value, ver
      return

    _initSubOtData: (data) ->
      fields = @_otFields
      fields[path] = field for path, field of data
      return

    _fetch: (targets, callback) ->
      return callback() unless @connected
      @socket.emit 'fetch', @_clientId, targets, callback

    _subAdd: (targets, callback) ->
      return callback() unless @connected
      @socket.emit 'subAdd', @_clientId, targets, callback

    _subRemove: (targets, callback) ->
      return callback() unless @connected
      @socket.emit 'subRemove', @_clientId, targets, callback

  server:

    _fetch: (targets, callback) ->
      store = @store
      @_clientIdPromise.on (clientId) ->
        store.fetch clientId, targets, callback

    _subAdd: (targets, callback) ->
      store = @store
      @_clientIdPromise.on (clientId) ->
        # Subscribe while the model still only resides on the server
        # The model is unsubscribed before sending to the browser
        store.subscribe clientId, targets, callback

    _subRemove: (targets, callback) ->
      store = @store
      @_clientIdPromise.on (clientId) ->
        store.unsubscribe clientId, targets, callback
