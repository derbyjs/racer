{EventEmitter} = require 'events'
socketio = require 'socket.io'
racer = require './racer'
Promise = require './util/Promise'
{createAdapter} = require './adapters'
transaction = require './transaction.server'
{eventRegExp, subPathToDoc} = require './path'
{bufferifyMethods, finishAfter} = require './util/async'
{Model} = racer.protected

# store = new Store
#   mode:
#     type: 'lww' || 'stm' || 'ot'
#     [journal]:
#       type: 'Redis'
#       port:
#       host:
#       db:
#       password:
#   db:        options literal or db adapter instance
#   clientId:  options literal or clientId adapter instance
#
# If an options literal is passed for db or clientId,
# it must contain a `type` property with the name of the adapter under
# `racer.adapters`. If the adapter has a `connect` method, it will be
# immediately called after instantiation.

Store = module.exports = (options = {}) ->
  EventEmitter.call this
  @_localModels = {}

  # Set up the conflict resolution mode
  modeOptions = if options.mode then Object.create options.mode else {type: 'lww'}
  modeOptions.store = this
  createMode = require './modes/' + modeOptions.type
  @_mode = createMode modeOptions

  @_db = db = createAdapter 'db', options.db || {type: 'Memory'}
  @_writeLocks = {}
  @_waitingForUnlock = {}

  @_clientId = clientId = createAdapter 'clientId', options.clientId || {type: 'Rfc4122_v4'}

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

  _commit: (txn, cb) ->
    @_mode.commit txn, cb

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
      return socket.emit 'fatalErr', 'missing clientId' unless clientId
      @mixinEmit 'socket', this, socket, clientId

  flushMode: (cb) -> @_mode.flush cb
  flushDb: (callback) -> @_db.flush callback
  flush: (callback) ->
    finish = finishAfter 2, callback
    @flushMode finish
    @flushDb finish

  disconnect: ->
    @_mode.disconnect?()
    @_pubSub.disconnect?()
    @_db.disconnect?()
    @_clientId.disconnect?()

  _checkVersion: (ver, clientStartId, cb) ->
    if @_mode.checkStartMarker
      return @_mode.checkStartMarker clientStartId, cb
    return cb null

  # This method is used by mutators on Store::
  _nextTxnId: (callback) ->
    @_txnCount = 0
    # Generate a special client id for store
    @_generateClientId (err, clientId) =>
      return callback err if err
      @_clientId = clientId
      @_nextTxnId = (callback) ->
        callback null, '#' + @_clientId + '.' + @_txnCount++
      @_nextTxnId callback

  _finishCommit: (txn, ver, callback) ->
    transaction.setVer txn, ver
    dbArgs = transaction.copyArgs txn
    method = transaction.getMethod txn
    dbArgs.push ver
    @_sendToDb method, dbArgs, (err, origDoc) =>
      @publish transaction.getPath(txn), 'txn', txn, {origDoc}
      callback err, txn if callback

  createModel: ->
    model = new Model
    model.store = this
    model._ioUri = @_ioUri

    if @_mode.startId
      model._startIdPromise = startIdPromise = new Promise
      model._bundlePromises.push startIdPromise
      @_mode.startId (err, startId) ->
        model._startId = startId
        startIdPromise.resolve err, startId

    localModels = @_localModels
    model._clientIdPromise = clientIdPromise = new Promise
    model._bundlePromises.push clientIdPromise
    @_generateClientId (err, clientId) ->
      model._clientId = clientId
      localModels[clientId] = model
      clientIdPromise.resolve err, clientId

    return model

  _unregisterLocalModel: (clientId) ->
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

    # Instert route after the first route with the same or lesser priority
    routes = @_routes[method]
    for {2: currPriority}, i in routes
      continue if priority <= currPriority
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
      # TODO Move this next line into a process.nextTick callback to avoid
      # growing the stack
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
    # Assign the db version to match the journal version
    # TODO This isn't necessary for LWW
    @_mode.version (err, ver) ->
      throw err if err
      db.version = ver
      return done()
