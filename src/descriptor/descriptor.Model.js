var Taxonomy = require('./Taxonomy')
  , noop = require('../util').noop
  , normArgs = require('./util').normArgs
  ;

module.exports = {
  type: 'Model'

, decorate: function (Model) {
    Model.prototype.descriptors = new Taxonomy;
    Model.dataDescriptor = function (conf) {
      var types = Model.prototype.descriptors
        , typeName = conf.name
        , type = types.type(typeName);
      if (type) return type;
      return types.type(typeName, conf);
    };
  }

, proto: {
    fetch: function (/* descriptors..., cb*/) {
      var args = normArgs(arguments)
        , descriptors = args[0]
        , cb = args[1]
        , self = this

        , scopedModels = []
        ;

      descriptors = this.descriptors.normalize(descriptors);

      this.descriptors.handle(this, descriptors, {
        registerFetch: true
        // Runs descriptorType.scopedResult and passes return value to this cb
      , scopedResult: function (scopedModel) {
          scopedModels.push(scopedModel);
        }
      });

      this._upstreamData(descriptors, function (err, data) {
        if (err) return cb(err);
        self._addData(data);
        cb.apply(null, [err].concat(scopedModels));
      });
    }

  , waitFetch: function (/* descriptors..., cb */) {
      var arglen = arguments.length
        , cb = arguments[arglen-1]
        , self = this;

      function newCb (err) {
        if (err === 'disconnected') {
          return self.once('connect', newCb);
        }
        cb.apply(null, arguments);
      };
      arguments[arglen-1] = newCb;
      this.fetch.apply(this, arguments);
    }

    // TODO Do some sort of subscription counting (like reference counting) to
    // trigger proper cleanup of a query in the QueryRegistry
  , subscribe: function (/* descriptors..., cb */) {
      var args = normArgs(arguments)
        , descriptors = args[0]
        , cb = args[1]
        , self = this

        , scopedModels = []
        ;

      descriptors = this.descriptors.normalize(descriptors);

      // TODO Don't subscribe to a given descriptor again if already
      // subscribed to the descriptor before (so that we avoid an additional fetch)

      this.descriptors.handle(this, descriptors, {
        registerSubscribe: true
      , scopedResult: function (scopedModel) {
          scopedModels.push(scopedModel);
        }
      });

      this._addSub(descriptors, function (err, data) {
        if (err) return cb(err);
        self._addData(data);
        self.emit('addSubData', data);
        cb.apply(null, [err].concat(scopedModels));
      });

      // TODO Cleanup function
      // return {destroy: fn }
    }

  , unsubscribe: function (/* descriptors..., cb */) {
      var args = normArgs(arguments)
        , descriptors = args[0]
        , cb = args[1]
        , self = this
        ;

      descriptors = this.descriptors.normalize(descriptors);

      this.descriptors.handle(this, descriptors, {
        unregisterSubscribe: true
      });

      // if (! descriptors.length) return;

      this._removeSub(descriptors, cb);
    }

  , _upstreamData: function (descriptors, cb) {
      if (!this.connected) return cb('disconnected');
      this.socket.emit('fetch', descriptors, this.scopedContext, cb);
    }

  , _addSub: function (descriptors, cb) {
      if (! this.connected) return cb('disconnected');
      this.socket.emit('subscribe', descriptors, this.scopedContext, cb);
    }

  , _removeSub: function (descriptors, cb) {
      if (! this.connected) return cb('disconnected');
      this.socket.emit('unsubscribe', descriptors, cb);
    }

    // TODO Associate contexts with path and query subscriptions
  , _subs: function () {
      var subs = []
        , types = this.descriptors
        , model = this;
      types.each( function (name, type) {
        subs = subs.concat(type.subs(model));
      });
      return subs;
    }

  , _addData: function (data) {
      var memory = this._memory;
      data = data.data;

      for (var i = 0, l = data.length; i < l; i++) {
        var triplet = data[i]
          , path  = triplet[0]
          , value = triplet[1]
          , ver   = triplet[2];
        if (ver == null) {
          // Adding data in this context should not be speculative _addData
          ver = -1;
          // TODO Investigate what scenarios cause this later
          // throw new Error('Adding data in this context should not be speculative _addData ' + path + ', ' + value + ', ' + ver);
        }
        var out = memory.set(path, value, ver);
        // Need this condition for scenarios where we subscribe to a
        // non-existing document. Otherwise, a mutator event would  e emitted
        // with an undefined value, triggering filtering and querying listeners
        // which rely on a document to be defined and possessing an id.
        if (value !== null && typeof value !== 'undefined') {
          // TODO Perhaps make another event to differentiate against model.set
          this.emit('set', [path, value], out);
        }
      }
    }
  }

, server: {
    _upstreamData: function (descriptors, cb) {
      var store = this.store
        , contextName = this.scopedContext
        , self = this;
      this._clientIdPromise.on(function (err, clientId) {
        if (err) return cb(err);
        var req = {
          targets: descriptors
        , clientId: clientId
        , session: self.session
        , context: store.context(contextName)
        };
        var res = {
          fail: cb
        , send: function (data) {
            store.emit('fetch', data, clientId, descriptors);
            cb(null, data);
          }
        };
        store.middleware.fetch(req, res);
      });
    }
  , _addSub: function (descriptors, cb) {
      var store = this.store
        , contextName = this.scopedContext
        , self = this;
      this._clientIdPromise.on(function (err, clientId) {
        if (err) return cb(err);
        // Subscribe while the model still only resides on the server. The
        // model is unsubscribed before sending to the browser.
        var req = {
          clientId: clientId
        , session: self.session
        , targets: descriptors
        , context: store.context(contextName)
        };
        var res = {
          fail: cb
        , send: function (data) {
            cb(null, data);
          }
        };
        store.middleware.subscribe(req, res);
      });
    }
  , _removeSub: function (descriptors, cb) {
      var store = this.store
        , context = this.scopedContext;
      this._clientIdPromise.on(function (err, clientId) {
        if (err) return cb(err);
        var mockSocket = {clientId: clientId};
        store.unsubscribe(mockSocket, descriptors, context, cb);
      });
    }
  }
};
