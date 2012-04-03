{EventEmitter} = require 'events'
socketio = require 'socket.io'
{Model} = racer = require './racer'
Promise = require './Promise'
{createAdapter} = require './adapters'
transaction = require './transaction.server'
{eventRegExp, subPathToDoc} = require './path'
{bufferifyMethods, finishAfter} = require './util/async'

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
  EventEmitter.call this
  @_localModels = {}
  @_journal = journal = createAdapter 'journal', options.journal || {type: 'Memory'}
  @_db = db = createAdapter 'db', options.db || {type: 'Memory'}
  @_writeLocks = {}
  @_waitingForUnlock = {}

  @_clientId = clientId = createAdapter 'clientId', options.clientId || {type: 'Rfc4122_v4'}

  # Add a @_commit method to this store based on the conflict resolution mode
  # TODO: Default mode should be 'ot' once supported
  @_commit = journal.commitFn this, options.mode || 'lww'

  @_generateClientId = clientId.generateFn()

  @mixinEmit 'init', this, options

  # Maps method => [function]
  @_routes = routes = {}
  for type in ['accessor', 'mutator']
    for method of Store[type]
      routes[method] = []
  db.setupRoutes this

  return

Store:: =

  __proto__: EventEmitter::

  listen: (to, namespace) ->
    io = socketio.listen to
    io.configure ->
      io.set 'browser client', false
      io.set 'transports', racer.get('transports')
    io.configure 'production', ->
      io.set 'log level', 1
    socketUri = if typeof to is 'number' then ':' + to else ''
    if namespace
      @setSockets io.of("/#{namespace}"), "#{socketUri}/#{namespace}"
    else
      @setSockets io.sockets, socketUri

  setSockets: (@sockets, @_ioUri = '') ->
    sockets.on 'connection', (socket) =>
      clientId = socket.handshake.query.clientId
      @mixinEmit 'socket', this, socket, clientId

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
    @_journal.startId (err, startId) ->
      return callback err if err
      if clientStartId != startId
        err = "clientStartId != startId (#{clientStartId} != #{startId})"
        return callback err
      callback null

  # This method is used by mutators on Store::
  _nextTxnId: (callback) ->
    @_txnCount = 0
    @_generateClientId (err, clientId) =>
      throw err if err
      @_clientId = clientId
      @_nextTxnId = (callback) ->
        callback null, '#' + @_clientId + '.' + @_txnCount++
      @_nextTxnId callback

  _finishCommit: (txn, ver, callback) ->
    transaction.setVer txn, ver
    args = transaction.getArgs(txn).slice()
    method = transaction.getMethod txn
    args.push ver
    @_sendToDb method, args, (err, origDoc) =>
      @publish transaction.getPath(txn), 'txn', txn, {origDoc}
      callback err, txn if callback

  createModel: ->
    model = new Model
    model.store = this
    model._ioUri = @_ioUri

    model._startIdPromise = startIdPromise = new Promise
    @_journal.startId (err, startId) ->
      model._startId = startId
      startIdPromise.resolve err, startId

    localModels = @_localModels
    model._clientIdPromise = clientIdPromise = new Promise
    @_generateClientId (err, clientId) ->
      model._clientId = clientId
      localModels[clientId] = model
      clientIdPromise.resolve err, clientId

    model._bundlePromises.push startIdPromise, clientIdPromise
    return model

  _unregisterLocalModel: (clientId) ->
    # Unsubscribe the model from PubSub events. It will be resubscribed
    # when the model connects over socket.io
    @unsubscribe clientId
    localModels = @_localModels
    delete localModels[clientId].store
    delete localModels[clientId]


  ## ACCESSOR ROUTERS/MIDDLEWARE ##

  route: (method, path, priority, fn) ->
    if typeof priority is 'function'
      fn = priority
      priority = 0
    else
      priority ||= 0
    re = eventRegExp path
    handler = [re, fn, priority]

    # Instert route before the first route with the same or lesser priority 
    routes = @_routes[method]
    for route, i in routes
      if handler[2] <= priority
        routes.splice i, 0, handler
        return this

    # Insert route at the end if it is the lowest priority
    routes.push handler
    return this

  _sendToDb: (method, args, done) ->
    [path, rest...] = args
    if method != 'get'
      pathToDoc = subPathToDoc path
      if pathToDoc of @_writeLocks
        return (@_waitingForUnlock[pathToDoc] ||= []).push [method, args, done]

      @_writeLocks[pathToDoc] = true
      done ||= (err) ->
        throw err if err
      lockingDone = =>
        delete @_writeLocks[pathToDoc]
        if buffer = @_waitingForUnlock[pathToDoc]
          [method, args, __done] = buffer.shift()
          delete @_waitingForUnlock[pathToDoc] unless buffer.length
          @_sendToDb method, args, __done
        done arguments...
    else
      lockingDone = done

    routes = @_routes[method]

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
      return fn.apply null, captures.concat(rest, [lockingDone, next])

Store.MODES = ['lww', 'stm']

bufferifyMethods Store, ['_sendToDb'],
  await: (done) ->
    db = @_db
    return done() if db.version isnt undefined
    @_journal.version (err, ver) ->
      throw err if err
      db.version = parseInt(ver, 10)
      return done()
