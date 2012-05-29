var QueryHub = require('./QueryHub')
  , path = require('../path')
  , splitPath = path.split
  , lookup = path.lookup
  , finishAfter = require('../util/async').finishAfter
  ;

module.exports = {
  type: 'Store'

, events: {
    init: function (store, opts) {
      store._queryCoordinator = new QueryHub(store);
    }
  , socket: function (store, socket, clientId) {
      socket.on('fetch', function (targets, cb) {
        // Only fetch data
        store.fetch(clientId, targets, cb);
      });

      socket.on('fetchCurrSnapshot', function (ver, clientStartId, subs) {
        store._onSnapshotRequest(ver, clientStartId, clientId, socket, subs);
      });
    }
  }

, proto: {

    // @param {QueryBuilder} query
    // @param {Function} cb
    query: function (queryJson, cb) {
      return this._queryCoordinator.fetch(queryJson, cb);
    }
  , fetch: function (clientId, targets, cb) {
      var data = []
        , self = this
        , finish = finishAfter(targets.length, function (err) {
            if (err) return cb(err);
            var out = {data: data};
            // Note that `out` may be mutated by ot or other plugins
            self.emit('fetch', out, clientId, targets);
            cb(null, out);
          });
      for (var i = 0, l = targets.length; i < l; i++) {
        var target = targets[i];
        var fetchFn = ('string' === typeof target)
                    ? this._fetchPathData
                    : this._fetchQueryData;
        // TODO We need to pass back array of document ids to assign to
        //      queries.someid.resultIds
        fetchFn.call(this, target, function (path, datum, ver) {
          data.push([path, datum, ver]);
        }, finish);
      }
    }
    // TODO Add in an optimization later since query._paginatedCache
    // can be read instead of going to the db. However, we must make
    // sure that the cache is a consistent snapshot of a given moment
    // in time. i.e., no versions of the cache should exist between
    // an add/remove combined action that should be atomic but currently
    // isn't
    // TODO Get version consistency right in face of concurrent writes
    // during query
  , _fetchQueryData: function (queryJson, eachDatumCb, finish) {
      this.query(queryJson, function (err, result, version) {
        if (err) return finish(err);
        var path;
        if (Array.isArray(result)) {
          for (var i = result.length; i--; ) {
            var doc = result[i];
            path = queryJson.from + '.' + doc.id;
            eachDatumCb(path, doc, version);
          }
        } else if (result) {
          path = queryJson.from + '.' + result.id;
          eachDatumCb(path, result, version);
        }
        finish(null);
      });
    }
  , _fetchPathData: function (path, eachDatumCb, finish) {
      var parts = splitPath(path)
        , root = parts[0]
        , remainder = parts[1];
      this.get(root, function (err, datum, ver) {
        if (err) return finish(err);
        if (typeof remainder === 'undefined') {
          eachDatumCb(path, datum, ver);
        } else {
          // The path looks like <root>.*.<remainder>
          // so set each property one level down
          patternMatchingDatum(root, remainder, datum, function (fullPath, datum) {
            eachDatumCb(fullPath, datum, ver);
          });
        }
        return finish(null);
      });
    }
  , _onSnapshotRequest: function (ver, clientStartId, clientId, socket, subs, shouldSubscribe) {
      var self = this;
      this._checkVersion(ver, clientStartId, function (err) {
        if (err) return socket.emit('fatalErr', err);
        if (shouldSubscribe) {
          self._pubSub.subscribe(clientId, subs);
        }
        self._mode.snapshotSince({
            ver: ver
          , clientId: clientId
          , subs: subs
        }, function (err, payload) {
          if (err) return socket.emit('fatalErr', err);
          var data = payload.data
            , txns = payload.txns
            , num  = self._txnClock.nextTxnNum(clientId);
          if (data) {
            socket.emit('snapshotUpdate:replace', data, num);
          } else if (txns) {
            var len;
            if (len = txns.length) {
              socket.__Ver = transaction.getVer(txns[len-1]);
            }
            socket.emit('snapshotUpdate:newTxns', txns, num);
          }
        });
      });
    }
  }
};

// @param {String} prefix is the part of the path up to ".*."
// @param {String} remainder is the part of the path after ".*."
// @param {Object} subDoc is the lookup value of the prefix
// @param {Function} eachDatumCb is the callback for each datum matching the pattern
function patternMatchingDatum (prefix, remainder, subDoc, eachDatumCb) {
  var parts          = splitPath(remainder)
    , appendToPrefix = parts[0]
    , remainder      = parts[1];
  for (var property in subDoc) {
    var value = subDoc[property];
    if (value.constructor !== Object && ! Array.isArray(value)) {
      // We can't lookup `appendToPrefix` on `value` in this case
      continue;
    }
    var newPrefix = prefix + '.' + property + '.' + appendToPrefix
      , newValue = lookup(appendToPrefix, value);
    if (typeof remainder === 'undefined') {
      eachDatumCb(newPrefix, newValue);
    } else {
      patternMatchingDatum(newPrefix, remainder, newValue, eachDatumCb);
    }
  }
}
