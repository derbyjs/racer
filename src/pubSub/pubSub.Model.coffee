transaction = require '../transaction'
{expand: expandPath, split: splitPath} = require '../path'
LiveQuery = require './LiveQuery'
{deserialize} = Query = require './Query'
{merge} = require '../util'
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
      querySubs = (query for _, query of model._querySubs)
      model._onLoad.push ['_loadSubs', model._pathSubs, querySubs]

    socket: (model, socket) ->
      memory = model._memory

      # When the store asks the browser model to resync with the store, then
      # the model should send the store its subscriptions and handle the
      # receipt of instructions to get the model state back in sync with the
      # store state (e.g., in the form of applying missed transaction, or in
      # the form of diffing to a received store state)
      socket.on 'resyncWithStore', (fn) ->
        fn model._subs(), memory.version, model._startId

      socket.on 'addDoc', ({doc, ns, ver}, num) ->
        # If the doc is already in the model, don't add it
        if (data = memory.get ns) && data[doc.id]
          # But add a null transaction anyway, so that `txnApplier`
          # doesn't hang because it never sees `num`
          model._addRemoteTxn null, num
        else
          txn = transaction.create ver: ver, id: null, method: 'set', args: ["#{ns}.#{doc.id}", doc]
          model._addRemoteTxn txn, num
          model.emit 'addDoc', "#{ns}.#{doc.id}", doc

        # TODO Resume here for reactive query code
#        for key, query of model._querySubs
#          results = model.query query
#          model.set query.orderedIdPath(), results.map ({id}) -> id

      socket.on 'rmDoc', ({doc, ns, hash, id, ver}, num) ->
        # TODO Optimize this by sending + using only ns.id
        for key, query of model._liveQueries
          # Don't remove the doc from if any other queries -- besides
          # the one that triggered the rmDoc -- match the doc
          if hash != key && query.test doc, "#{ns}.#{id}"
            return model._addRemoteTxn null, num

        txn = transaction.create ver: ver, id: null, method: 'del', args: ["#{ns}.#{id}"]
        model._addRemoteTxn txn, num
        model.emit 'rmDoc', ns + '.' + id, doc

  proto:
    _loadSubs: (@_pathSubs, querySubList) ->
      querySubs = @_querySubs
      liveQueries = @_liveQueries
      for item in querySubList
        query = deserialize item
        hash = query.hash()
        querySubs[hash] = query
        liveQueries[hash] = new LiveQuery query
      return

    query: (namespace, opts) ->
      q = new Query namespace
      if opts then for k, v of opts
        switch k
          when 'byKey', 'skip', 'limit', 'sort'
            q = q[k] v
          when 'where'
            for property, conditions of v
              q = q.where(property)
              if conditions.constructor == Object
                for method, args of conditions
                  q = q[method] args
              else
                q = q.equals conditions
          when 'only', 'except'
            q = q[k] v...
          else
            throw new Error "Unsupported key #{k}"
      return q

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

      @_fetch newTargets, (err, data) =>
        @_initSubData data
        callback err, out...

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
            liveQueries[hash] = new LiveQuery target
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
      return callback null, out...  unless newTargets.length

      @_addSub newTargets, (err, data) =>
        return callback err if err
        @_initSubData data
        callback null, out...

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
      return callback()  unless newTargets.length

      @_removeSub newTargets, callback

    _initSubData: (data) ->
      @emit 'subInit', data
      @_initData data

    _initData: (data) ->
      memory = @_memory
      for [path, value, ver] in data.data
        memory.set path, value, ver
      return

    _fetch: (targets, callback) ->
      return callback 'disconnected'  unless @connected
      @socket.emit 'fetch', targets, callback

    _addSub: (targets, callback) ->
      return callback 'disconnected'  unless @connected
      @socket.emit 'addSub', targets, callback

    _removeSub: (targets, callback) ->
      return callback 'disconnected'  unless @connected
      @socket.emit 'removeSub', targets, callback

    _subs: ->
      subs = Object.keys @_pathSubs
      subs.push query for _, query of @_querySubs
      return subs

  server:

    _fetch: (targets, callback) ->
      store = @store
      @_clientIdPromise.on (err, clientId) ->
        return callback err if err
        store.fetch clientId, targets, callback

    _addSub: (targets, callback) ->
      @_clientIdPromise.on (err, clientId) =>
        return callback err if err
        # Subscribe while the model still only resides on the server
        # The model is unsubscribed before sending to the browser
        @store.subscribe clientId, targets, callback

    _removeSub: (targets, callback) ->
      store = @store
      @_clientIdPromise.on (err, clientId) ->
        return callback err if err
        store.unsubscribe clientId, targets, callback
