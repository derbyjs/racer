// TODO Cache more results than we need (cache >= 1 prev page result)
// TODO Handle all errors
var QueryNode = require('./QueryNode')
  , QueryBuilder = require('./QueryBuilder')
  , transaction = require('../transaction')
  , pathUtils = require('../path')
  , lookup = pathUtils.lookup
  , objectExcept = pathUtils.objectExcept
  , util = require('../util')
  , countWhile = util.countWhile
  , indexOf = util.indexOf
  , deepCopy = util.deepCopy
  , deepEqual = util.deepEqual
  , DbMemory = require('../adapters/db-memory').adapter
  ;

function equivIds (docA, docB) {
  return docA.id === docB.id
}

module.exports = PaginatedQueryNode;

function PaginatedQueryNode (queryJson) {
  QueryNode.call(this, queryJson);
  this._cache = null; // Caches the results
}

PaginatedQueryNode.prototype.__proto__ = QueryNode.prototype;

// NOTE- Since we can read results directly from the cache after cacheing,
// we must make sure that the cache is a consistent snapshot of a given moment
// in time -- i.e., no versions of the cache should exist between an add/remove
// combined action that should be atomic but currently isn't.
PaginatedQueryNode.prototype.results = function results (db, cb) {
  var dbQuery = new db.Query(this.json)
    , cache = this._cache
    , self = this;

  if (cache) return cb(err, cache);

  return dbQuery.run(db, function (err, found) {
    if (Array.isArray(found)) {
      self._cache = found;

      if (db instanceof DbMemory) {
        // So the cache members don't update in place when the memory adapter
        // changes them in a different context/scenario. Only need to do this
        // if we're using DbMemory
        self._cache = self._cache.map(deepCopy);
      }
    }
    cb(err, found);
  });
};

function publishFn (pubSub, type, channel, data) {
  pubSub.publish({type: type, params: { channel: channel, data: data }});
}

function publishAddDoc (pubSub, channel, ns, doc, ver) {
  publishFn(pubSub, 'addDoc', channel, {ns: ns, doc: doc, ver: ver});
}

function publishRmDoc (pubSub, channel, ns, doc, ver) {
  publishFn(pubSub, 'rmDoc', channel, {ns: ns, id: doc.id, ver: ver});
}

PaginatedQueryNode.prototype.maybePublish = function maybePublish (newDoc, oldDoc, txn, services, cb) {
  var cache = this._cache
    , store = services.store
    , pubSub = services.pubSub;

  if (!cache) {
    var self = this;
    // The following function implicitly sets the cache
    return this.results(store._db, function (err, results) {
      if (err) return cb(err);
      return self.maybePublish(newDoc, oldDoc, txn, services, cb);
    });
  }

  var path = transaction.getPath(txn)
    , ver = transaction.getVer(txn)
    , ns = path.substring(0, path.indexOf('.'))

    , filter = this.query._filter
    , oldDocPasses = filter(oldDoc, ns)
    , newDocPasses = filter(newDoc, ns)

    , self = this;

  if (!oldDocPasses && !newDocPasses) return;

  var cache = this._cache
    , json = this.json
    , sort = json.sort
    , limit = json.limit
    , skip = json.skip
    , channel = '$q.' + this.hash;

  /* Figure out movement of the doc */
  var delta = pageDelta(this.query._comparator, cache, oldDoc, newDoc);

  // TODO Keep in mind that we are querying the state *after* the txn has been
  // committed and written to the db.

  // TODO Handle sanity check failures
  if (oldDocPasses && newDocPasses) {

    switch (deltaType(delta, cache.length, json.limit)) {
      case 'mv-prior->prior': return;
      case 'mv-prior->curr':
        if (delta.to === Infinity) {
          cache.push(newDoc);
        } else {
          cache.splice(delta.to, 0, newDoc);
        }
        var docToRm = cache.shift();
        publishRmDoc(pubSub, self.channel, ns, docToRm, ver);
        publishAddDoc(pubSub, self.channel, ns, newDoc, ver);
        return;
      case 'mv-prior->later':
        return fetchSlice(json, json.limit - 2, json.limit, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return console.error(err);
          }

          var sanityDoc = docs[0]
            , docToAdd  = docs[1];
          if (docToAdd && deepEqual(sanityDoc, cache[cache.length-1])) {
            cache.push(docToAdd);
            publishAddDoc(pubSub, self.channel, ns, docToAdd, ver);
          }

          var docToRm = cache.shift();
          publishRmDoc(pubSub, self.channel, ns, docToRm, ver);
        });
      case 'mv-curr->prior':
        return fetchSlice(json, 0, 2, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return console.error(err);
          }

          var sanityDoc = docs[1]
            , docToAdd  = docs[0]
            , isSane = deepEqual(sanityDoc, cache[0]);
          if (isSane) {
            if (-1 === indexOf(cache, docToAdd, equivIds)) {
              publishRmDoc(pubSub, self.channel, ns, newDoc, ver);
              publishAddDoc(pubSub, self.channel, ns, docToAdd, ver);
            } else { // This means the the mv is meant to be curr->curr
              publishFn(pubSub, 'txn', self.channel, txn);
            }
            cache.splice(delta.from, 1);
            cache.unshift(docToAdd);
          }
        });
      case 'mv-curr->curr':
        var from = delta.from
          , to   = delta.to;
        if (from < to) {
          cache.splice(to, 0, newDoc);
          cache.splice(from, 1);
        } else { // from > to
          cache.splice(from, 1);
          cache.splice(to, 0, newDoc);
        }
        return publishFn(pubSub, 'txn', self.channel, txn);
      case 'mv-curr->later':
        return fetchSlice(json, json.limit - 2, json.limit, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return console.error(err);
          }

          var sanityCheck = docs[0]
            , docToAdd    = docs[1];
          // TODO Replace strict equals with deepEquals
          if (docToAdd && deepEqual(sanityCheck, cache[cache.length - 1])) {
            cache.push(docToAdd);
            publishAddDoc(pubSub, self.channel, ns, docToAdd, ver);
          }

          cache.splice(delta.from, 1);
          publishRmDoc(pubSub, self.channel, ns, newDoc, ver);
        });
      case 'mv-later->prior':
        return fetchSlice(json, 0, 2, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return console.error(err);
          }

          var sanityCheck = docs[1]
            , docToAdd    = docs[0];
          if (deepEqual(sanityCheck, cache[0])) {
            cache.unshift(docToAdd);
            publishAddDoc(pubSub, self.channel, ns, docToAdd, ver);
          }
          var docToRm = cache.pop();
          publishRmDoc(pubSub, self.channel, ns, docToRm, ver);
        });
      case 'mv-later->curr':
        cache.splice(delta.to, 0, newDoc);
        publishAddDoc(pubSub, self.channel, ns, newDoc, ver);
        var docToRm = cache.pop();
        publishRmDoc(pubSub, self.channel, ns, docToRm, ver);
      case 'mv-later->later': return;
      default: throw new Error();
    }
  }

  if (oldDocPasses && !newDocPasses) {
    switch (delta.from) {
      case Infinity: return;
      case -Infinity:
        return fetchSlice(json, json.limit - 2, json.limit, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return console.error(err);
          }

          var sanityDoc = docs[0]
            , docToAdd  = docs[1];
          if (docToAdd && deepEqual(sanityDoc, cache[cache.length-1])) {
            cache.push(docToAdd);
            publishAddDoc(pubSub, self.channel, ns, docToAdd, ver);
          }
          var docToRm = cache.shift();
          publishRmDoc(pubSub, self.channel, ns, docToRm, ver);
        });
      default:
        return fetchSlice(json, json.limit - 2, json.limit, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return console.error(err);
          }

          cache.splice(delta.from, 1);

          var sanityDoc = docs[0]
            , docToAdd  = docs[1];
          if (docToAdd && deepEqual(sanityDoc, cache[cache.length-1])) {
            cache.push(docToAdd);
            publishAddDoc(pubSub, self.channel, ns, docToAdd, ver);
          }
          publishRmDoc(pubSub, self.channel, ns, oldDoc, ver);
        });
    }
  }

  if (!oldDocPasses && newDocPasses) {
    switch (delta.to) {
      case Infinity: return;
      case null:
      case -Infinity:

        // If we're on the first page, interpret -Infinity === delta.to to mean
        // that we should insert this at the beginning of the cache.
        if (skip === 0) {
          if (cache.length === json.limit) {
            var docToRm = cache.pop();
            publishRmDoc(pubSub, self.channel, ns, docToRm, ver);
          }
          cache.unshift(newDoc);
          return publishAddDoc(pubSub, self.channel, ns, newDoc, ver);
        }

        // Otherwise, grab the first 2 results of this page from the db. This
        // assumes that the mutation has already affected the db.
        var nextQueryJson = Object.create(json, {
          limit: { value: 2 }
        });
        var dbQuery = new store._db.Query(nextQueryJson);
        return dbQuery.run(store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return console.error(err);
          }
          if (deepEqual(docs[1], cache[0])) {
            if (cache.length === json.limit) {
              var docToRm = cache.pop();
              publishRmDoc(pubSub, self.channel, ns, docToRm, ver);
            }
            cache.unshift(docs[0]);
            publishAddDoc(pubSub, self.channel, ns, docs[0], ver);
          }
        });

      default:
        if (cache.length === json.limit) {
          var docToRm = cache.pop();
          publishRmDoc(pubSub, this.channel, ns, docToRm, ver);
        }
        cacheInsert(cache, newDoc, delta.to);
        publishAddDoc(pubSub, this.channel, ns, newDoc, ver);
        return;
    }
  }
};

// TODO Wrap this inside fetchFirstOfNextPage(store._db, json, cache, cb) and
// fetchLastOfPriorPage(store._db, json, cache, cb)
function fetchSlice (queryJson, from, to, db, cb) {
  var nextQueryJson = Object.create(queryJson, {
      limit: { value: to - from }
    , skip:  { value: queryJson.skip + from }
  });
  var dbQuery = new db.Query(nextQueryJson);
  return dbQuery.run(db, cb);
}

function cacheInsert (cache, doc, atIndex) {
  var x = cache[atIndex]
  if (x && x.id !== doc.id) {
    // Check because loading the cache the first time will include the
    // doc in the cache, so we want to insert a duplicate.
    cache.splice(atIndex, 0, doc);
  }
}

// Assume `oldDoc` changed to `newDoc`. This could impact the paginated query
// result `cache` where the query has `skip` and `limit` parameters. The
// purpose of the `pageDelta` function is to return an object that
// encapsulates information about how the change from `oldDoc` to `newDoc`
// should impact cache. The returned object has a `type` key whose value is of
// the form "mv-X->Y" where X and Y are members of {'prior', 'curr', 'later'}
// where
// - "mv-curr->prior" means that `oldDoc` belonged in the current page
//   associated with the query, but the change resulting in `newDoc` causes
//   `newDoc` to belong in a page that occurs before the current page.
// - "mv-curr->later" means that `oldDoc` belonged in the current page
//   associated with the query, but the change resulting in `newDoc` causes
//   `newDoc` to belong in a page that occurs after the current page.
// - "mv-curr->curr" means that both `oldDoc` belonged in the current page
//   associated query, and `newDoc` still belongs in the current page. Usually,
//   this means that `oldDoc` needs to move to a different index in the cache.
// - etc.
// @param {Array} cache is the last cache of the query results
// @param {Array} sort looks like ['fieldA', 'asc', 'fieldB', 'desc', ...]
// @param {Number} skip is the number of results to skip for the query
// @param {Object} oldDoc
// @param {Object} newDoc
function pageDelta (comparator, cache, oldDoc, newDoc) {
  var delta = {};
  if (oldDoc) delta.from = relPosition(comparator, cache, oldDoc);
  if (newDoc) delta.to   = relPosition(comparator, cache, newDoc);

  // TODO Move this elsewhere
//  // If the doc was already in the cache, then interpret Infinity and -Infinity
//  // differently
//  if (oldDoc && -1 !== indexOf(cache, oldDoc, equivId)) {
//    if (delta.to === Infinity) {
//      delta.to === cache.length;
//    } else if (delta.to === -Infinity) {
//      delta.to = 0;
//    }
//  }
  return delta;
}

function relPosition (comparator, cache, doc) {
  var cacheLen = cache.length;

  if (cacheLen === 0) return null;

  var firstDoc = cache[0]
    , lastDoc  = cache[cacheLen-1];
  if (!firstDoc) return;
  switch (comparator(doc, firstDoc)) {
    case -1: return -Infinity;
    case  0: return 0;
    case  1:
      if (!lastDoc) return;
      switch (comparator(doc, lastDoc)) {
        case  1: return Infinity;
        case  0: return cacheLen - 1;
        case -1:
          for (var i = 0; i < cacheLen; i++) {
            if (comparator(doc, cache[i]) <= 0) return i;
          }
          return cacheLen - 1;
      }
  }
}

function deltaType (delta, cacheLen, queryLimit) {
  var from = delta.from
    , to   = delta.to;
  if (from === -Infinity) {
    if (to === -Infinity) return 'mv-prior->prior';
    if (to === Infinity && cacheLen === queryLimit) return 'mv-prior->later';
    return 'mv-prior->curr';
  }

  if (from === Infinity) {
    if (to === -Infinity) return 'mv-later->prior';
    if (to === Infinity) return 'mv-later->later';
    return 'mv-later->curr';
  }

  if (to === -Infinity) return 'mv-curr->prior';
  if (to === Infinity) return 'mv-curr->later';
  return 'mv-curr->curr';
}
