var EventEmitter = require('events').EventEmitter
  , socketio = require('socket.io')
  , racer = require('./racer')
  , Promise = require('./util/Promise')
  , createAdapter = require('./adapters').createAdapter
  , transaction = require('./transaction.server')
  , pathUtils = require('./path')
  , eventRegExp = pathUtils.eventRegExp
  , subPathToDoc = pathUtils.subPathToDoc
  , asyncUtils = require('./util/async')
  , bufferifyMethods = asyncUtils.bufferifyMethods
  , finishAfter = asyncUtils.finishAfter
  , Model = racer.protected.Model
  , debugGenerator = require('debug')
  , socketDebug = debugGenerator('socket-client-id')
  , racerDebug  = debugGenerator('racer')
  ;

module.exports = Store;

/**
 * Initialize a new `Store`.
 *
 * var store = new Store({
 *   mode: {
 *     type: 'lww' || 'stm' || 'ot'
 *   , [journal]: {
 *       type: 'Redis'
 *     , port: xxx
 *     , host: xxx
 *     , db: xxx
 *     , password: xxx
 *     }
 *   }
 * , db: options literal or db adapter instance
 * , clientId: options literal of clientId adapter instance
 * });
 *
 * If an options literal is passed for db or clientId, it must contain a `type`
 * property with the name of the adapter under `racer.adapters`. If the adapter
 * has a `connect` method, it will be immediately called after instantiation.
 *
 * @param {Object} options
 * @api public
 */
function Store (options) {
  if (! options) options = {};
  EventEmitter.call(this);
  this._localModels = {};

  // Set up the conflict resolution mode
  var modeOptions = options.mode
                  ? Object.create(options.mode)
                  : { type: 'lww' };
  modeOptions.store = this;
  var createMode = require('./modes/' + modeOptions.type);
  this._mode = createMode(modeOptions);

  var db = this._db = createAdapter('db', options.db || { type: 'Memory' });
  this._writeLocks = {};
  this._waitingForUnlock = {};

  var clientId = this._clientId = createAdapter('clientId', options.clientId || { type: 'Rfc4122_v4' });

  this._generateClientId = clientId.generateFn();

  this._clientSockets = {};

  this.mixinEmit('init', this, options);

  // Maps method => [function]
  var routes = this._routes = {}
    , types = ['accessor', 'mutator'];
  for (var i = types.length; i--; ) {
    for (var method in Store[types[i]]) {
      routes[method] = [];
    }
  }
  db.setupRoutes(this);
}

Store.prototype.__proto__ = EventEmitter.prototype;

Store.prototype.listen = function (to, namespace) {
  var io = socketio.listen(to);
  io.configure( function () {
    io.set('browser.client', false);
    io.set('transports', racer.get('transports'));
    if (racer.get('polling duration')) {
      io.set('polling duration', racer.get('polling duration'));
    }
  });
  io.configure('production', function () {
    io.set('log level', 1);
  });
  io.configure('development', function () {
    io.set('log level', 0);
  });
  this.mixinEmit('socketio', this, io);
  socketUri = (typeof to === 'number')
            ? ':'
            : '';
  if (namespace) {
    this.setSockets(io.of('/' + namespace), socketUri + '/' + namespace);
  } else {
    this.setSockets(io.sockets, socketUri);
  }
};

Store.prototype.setSockets = function (sockets, ioUri) {
  this.sockets = sockets;
  this._ioUri = ioUri || (ioUri = '');
  var self = this;
  sockets.on('connection', function (socket) {
    // TODO Do not decorate socket directly. This is brittle if socketio
    // decides to add a clientId property to socket objects. Perhaps instead
    // pass around a connection object that has references to clientId, socket,
    // session, etc
    var clientId = socket.clientId = socket.handshake.query.clientId;

    /* Loggin */
    socketDebug('ON CONNECTION', clientId);

    if (!clientId) {
      return socket.emit('fatalErr', 'missing clientId');
    }
    self._clientSockets[clientId] = socket;
    self.mixinEmit('socket', self, socket, clientId);
  });
};

Store.prototype.flushMode = function (callback) {
  this._mode.flush(callback);
};

Store.prototype.flushDb = function (callback) {
  this._db.flush(callback);
};

Store.prototype.flush = function (callback) {
  var finish = finishAfter(2, callback);
  this.flushMode(finish);
  this.flushDb(finish);
};

Store.prototype.disconnect = function () {
  var adapters = ['_mode', '_pubSub', '_db', '_clientId'];
  for (var i = adapters.length; i--; ) {
    var adapter = this[adapters[i]];
    adapter.disconnect && adapter.disconnect();
  }
};

// TODO We never use version argument here
Store.prototype._checkVersion = function (version, clientStartId, callback) {
  var mode = this._mode;
  return (mode.checkStartMarker) ? mode.checkStartMarker(clientStartId, callback)
                                 : callback(null);
};

// This method is used by mutators on Store.prototype
Store.prototype._nextTxnId = function (callback) {
  var self = this;
  this._txnCount = 0;
  // Generate a special client id for store
  this._generateClientId( function (err, clientId) {
    if (err) return callback(err);
    self._clientId = clientId;
    self._nextTxnId = function (callback) {
      callback(null, '#' + self._clientId + '.' + self._txnCount++);
    };
    self._nextTxnId(callback);
  });
};

Store.prototype._finishCommit = function (txn, ver, callback) {
  transaction.setVer(txn, ver);
  var dbArgs = transaction.copyArgs(txn)
    , method = transaction.getMethod(txn)
    , self = this;
  dbArgs.push(ver);
  this._sendToDb(method, dbArgs, function (err, origDoc) {
    if (err) {
      if (callback) return callback(err, txn);
      return racerDebug(err);
    }
    self.publish(transaction.getPath(txn), 'txn', txn, {origDoc: origDoc});
    if (callback) callback(null, txn);
  });
};

Store.prototype.createModel = function () {
  var model = new Model({
    store: this
  , _ioUri: this._ioUri
  });

  if (this._mode.startId) {
    var startIdPromise = model._startIdPromise = new Promise();
    model._bundlePromises.push(startIdPromise);
    this._mode.startId( function (err, startId) {
      model._startId = startId;
      startIdPromise.resolve(err, startId);
    });
  }

  var localModels = this._localModels;
  var clientIdPromise = model._clientIdPromise = new Promise();
  model._bundlePromises.push(clientIdPromise);
  this._generateClientId( function (err, clientId) {
    model._clientId = clientId;
    localModels[clientId] = model;
    clientIdPromise.resolve(err, clientId);
  });

  return model;
};

Store.prototype._unregisterLocalModel = function (clientId) {
  var localModels = this._localModels;
  delete localModels[clientId].store;
  delete localModels[clientId];
};

/* Accessor routers/middleware */

Store.prototype.route = function (method, path, priority, fn) {
  if (typeof priority === 'function') {
    fn = priority;
    priority = 0;
  } else {
    priority || (priority = 0);
  }
  var regexp = eventRegExp(path)
    , handler = [regexp, fn, priority];

  // Insert route after the first route with the same or lesser priority
  var routes = this._routes[method];
  for (var i = 0, l = routes.length; i < l; i++) {
    var currPriority = routes[i][2];
    if (priority <= currPriority) continue;
    routes.splice(i, 0, handler);
    return this;
  }

  // Insert route at the end if it is the lowest priority
  routes.push(handler);
  return this;
};

Store.prototype._sendToDb = function (method, args, done) {
  var path = args[0]
    , rest = args.slice(1)
    , lockingDone;
  if (method !== 'get') {
    var pathToDoc = subPathToDoc(path)
      , writeLocks = this._writeLocks
      , queuesByPath = this._waitingForUnlock;
    if (pathToDoc in writeLocks) {
      var queue = queuesByPath[pathToDoc] || (queuesByPath[pathToDoc] = []);
      return queue.push([method, args, done]);
    }

    writeLocks[pathToDoc] = true;
    if (! done) done = function (err) { if (err) throw err; };
    var self = this;
    lockingDone = function () {
      delete writeLocks[pathToDoc];
      var buffer = queuesByPath[pathToDoc];
      if (buffer) {
        var triplet = buffer.shift()
          , method = triplet[0]
          , args   = triplet[1]
          , __done = triplet[2];
        if (! buffer.length) delete queuesByPath[pathToDoc];
        self._sendToDb(method, args, __done);
      }
      done.apply(null, arguments);
    }
  } else {
    lockingDone = done;
  }

  var routes = this._routes[method];

  var i = 0;

  function next () {
    var handler = routes[i++];
    if (! handler) {
      throw new Error('No persistence handler for ' + method + '(' + args.join(',') + ')');
    }
    var regexp = handler[0]
      , fn     = handler[1]
      , match;
    // TODO Move this next line into process.nextTick callback to avoid growing
    // the stack?
    if (path !== '' && ! (match = path.match(regexp))) {
      return next();
    }
    var captures = (path === '')       ? ['']
                 : (match.length > 1)  ? match.slice(1)
                                       : [match[0]];
    return fn.apply(null, captures.concat(rest, [lockingDone, next]));
  }

  return next();
};

// TODO This is not DRY if we have to register more modes
Store.MODES = ['lww', 'stm'];

bufferifyMethods(Store, ['_sendToDb'], {
  await: function (done) {
    var db = this._db;
    if (typeof db.version !== 'undefined') return done();
    // Assign the db version to match the journal version
    // TODO This is not necessary for LWW
    this._mode.version( function (err, ver) {
      if (err) throw err;
      db.version = ver;
      return done();
    });
  }
});
