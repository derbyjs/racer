socketio = require 'socket.io'
{Model} = racer = require './racer'
Promise = require './Promise'
transaction = require './transaction.server'
{eventRegExp} = require './path'
{bufferify, finishAfter} = require './util'

# store = new Store
#   mode:      'lww' || 'stm' || 'ot'
#   journal:   options literal or journal adapter instance
#   pubSub:    options literal or pubSub adapter instance
#   db:        options literal or db adapter instance
#   clientId:  options literal or clientId adapter instance
#
# If an options literal is passed for journal, pubSub, db, or clientId,
# it must contain a `type` property with the name of the adapter under
# `racer.adapters`. If the adapter has a `connect` method, it will be
# immediately called after instantiation.

Store = module.exports = (options = {}) ->
  @_localModels = {}

  @_journal = journal = createAdapter options, 'journal', type: 'Memory'
  @_pubSub = pubSub = createAdapter options, 'pubSub', type: 'Memory'
  @_db = db = createAdapter options, 'db', type: 'Memory'
  @_clientId = clientId = createAdapter options, 'clientId', type: 'Rfc4122_v4'

  # Add a @_commit method to this store based on the conflict resolution mode
  # TODO: Default mode should be 'ot' once supported
  @_commit = journal.commitFn this, options.mode || 'lww'

  @_generateClientId = clientId.generateFn()

  @mixinEmit 'init', this

  @_persistenceRoutes = persistenceRoutes = {}
  @_defaultPersistenceRoutes = defaultPersistenceRoutes = {}
  for type in ['accessor', 'mutator']
    for method of Store[type]
      persistenceRoutes[method] = []
      defaultPersistenceRoutes[method] = []
  db.setupDefaultPersistenceRoutes this

  return

Store:: =

  listen: (to, namespace) ->
    io = socketio.listen to
    io.configure ->
      io.set 'browser client', false
      io.set 'transports', racer.transports
    io.configure 'production', ->
      io.set 'log level', 1
    socketUri = if typeof to is 'number' then ':' + to else ''
    if namespace
      @setSockets io.of("/#{namespace}"), "#{socketUri}/#{namespace}"
    else
      @setSockets io.sockets, socketUri

  setSockets: (@sockets, @_ioUri = '') ->
    sockets.on 'connection', (socket) =>
      @mixinEmit 'socket', this, socket

  flushJournal: (callback) -> @_journal.flush callback
  flushDb: (callback) -> @_db.flush callback
  flush: (callback) ->
    finish = finishAfter 2, callback
    @flushJournal finish
    @flushDb finish

  disconnect: ->
    @_journal.disconnect?()
    @_pubSub.disconnect?()
    @_db.disconnect?()
    @_clientId.disconnect?()

  _checkVersion: (socket, ver, clientStartId, callback) ->
    # TODO: Map the client's version number to the journal's and update
    # the client with the new startId & version when possible
    @_journal.startId (startId) ->
      if clientStartId != startId
        err = "clientStartId != startId (#{clientStartId} != #{startId})"
        socket.emit 'fatalErr', err
        return callback err
      callback null

  # This method is used by mutators on Store::
  _nextTxnId: (callback) ->
    @_txnCount = 0
    @_generateClientId (err, clientId) =>
      throw err if err
      @_clientId = clientId
      @_nextTxnId = (callback) ->
        callback '#' + @_clientId + '.' + @_txnCount++
      @_nextTxnId callback

  _finishCommit: (txn, ver, callback) ->
    transaction.base txn, ver
    args = transaction.args(txn).slice()
    method = transaction.method txn
    args.push ver
    @_sendToDb method, args, (err, origDoc) =>
      # TODO De-couple publish from db write
      @publish transaction.path(txn), {txn}, {origDoc}
      callback err, txn  if callback

  createModel: ->
    model = new Model
    model.store = this
    model._ioUri = @_ioUri

    model._startIdPromise = startIdPromise = new Promise
    @_journal.startId (startId) ->
      model._startId = startId
      startIdPromise.fulfill startId

    localModels = @_localModels
    model._clientIdPromise = clientIdPromise = new Promise
    @_generateClientId (err, clientId) ->
      throw err if err
      model._clientId = clientId
      localModels[clientId] = model
      clientIdPromise.fulfill clientId

    model._bundlePromises.push startIdPromise, clientIdPromise
    return model

  _unregisterLocalModel: (clientId) ->
    # Unsubscribe the model from PubSub events. It will be resubscribed
    # when the model connects over socket.io
    @unsubscribe clientId
    localModels = @_localModels
    delete localModels[clientId].store
    delete localModels[clientId]


  ## PERSISTENCE ROUTER ##

  route: (method, path, fn) ->
    re = eventRegExp path
    @_persistenceRoutes[method].push [re, fn]
    return this

  defaultRoute: (method, path, fn) ->
    re = eventRegExp path
    @_defaultPersistenceRoutes[method].push [re, fn]
    return this

  _sendToDb:
    bufferify '_sendToDb',
      await: (done) ->
        db = @_db
        return done() if db.version isnt undefined
        @_journal.version (err, ver) ->
          throw err if err
          db.version = parseInt(ver, 10)
          return done()
      fn: (method, args, done) ->
        routes = @_persistenceRoutes[method].concat @_defaultPersistenceRoutes[method]
        [path, rest...] = args
        done ||= (err) ->
          throw err if err
        i = 0
        do next = ->
          unless handler = routes[i++]
            throw new Error "No persistence handler for #{method}(#{args.join(', ')})"
          [re, fn] = handler
          return next() unless path == '' || (match = path.match re)
          captures = if path == ''
              ['']
            else if match.length > 1
              match[1..]
            else
              [match[0]]
          return fn.apply null, captures.concat(rest, [done, next])


Store.MODES = ['lww', 'stm']

createAdapter = (storeOptions, adapterType, defaultOptions) ->
  options = storeOptions[adapterType] || defaultOptions
  if typeof options is 'string'
    options = type: options
  if options.type
    adapter = racer.createAdapter adapterType, options
    adapter.connect?()
    return adapter
  return options
