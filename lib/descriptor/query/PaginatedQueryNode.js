// TODO Cache more results than we need (cache >= 1 prev page result)
// TODO Handle all errors
var QueryNode     = require('./QueryNode')
  , QueryBuilder  = require('./QueryBuilder')
  , transaction   = require('../../transaction')
  , pathUtils     = require('../../path')
  , lookup        = pathUtils.lookup
  , objectExcept  = pathUtils.objectExcept
  , util          = require('../../util')
  , countWhile    = util.countWhile
  , indexOf       = util.indexOf
  , deepCopy      = util.deepCopy
  , deepEqual     = util.deepEqual
  , DbMemory      = require('../../adapters/db-memory').adapter
  , debug         = require('debug')('error')
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

  if (cache) return cb(null, cache);

  return dbQuery.run(db, function (err, found) {
    var cache = self._cache = found;

    if (Array.isArray(found)) {
      if (db instanceof DbMemory) {
        // So the cache members don't update in place when the memory adapter
        // changes them in a different context/scenario. Only need to do this
        // if we're using DbMemory
        cache = self._cache = cache.map(deepCopy);
      }
    }
    cb(err, cache);
  });
};

PaginatedQueryNode.prototype.shouldPublish = function (newDoc, oldDoc, txn, store, cb) {
  //return; // TODO Support PaginatedQueryNodes later

  var cache = this._cache;

  if (!cache) {
    var self = this;
    // The following function implicitly sets the cache
    return this.results(store._db, function (err, results) {
      if (err) return cb(err);
      return self.shouldPublish(newDoc, oldDoc, txn, store, cb);
    });
  }

  var path = transaction.getPath(txn)
    , ver = transaction.getVer(txn)
    , ns = path.substring(0, path.indexOf('.'));

  if (ns !== this.ns) return false;

  var filter = this.query._filter
    , oldDocPasses = oldDoc && filter(oldDoc)
    , newDocPasses = newDoc && filter(newDoc)

    , self = this;

  if (!oldDocPasses && !newDocPasses) return cb(null, false);

  var json = this.json
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
      case 'mv-prior->prior': return cb(null, false);
      case 'mv-prior->curr':
        if (delta.to === Infinity) {
          cache.push(newDoc);
        } else {
          cache.splice(delta.to, 0, newDoc);
        }
        var docToRm = cache.shift();
        return cb(null, [['rmDoc', ns, ver, docToRm, docToRm.id], ['addDoc', ns, ver, newDoc]]);
      case 'mv-prior->later':
        return fetchSlice(json, json.limit - 2, json.limit, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return debug(err);
          }

          var sanityDoc = docs[0]
            , docToAdd  = docs[1]
            , messages = [];
          if (docToAdd && deepEqual(sanityDoc, cache[cache.length-1])) {
            cache.push(docToAdd);
            messages.push(['addDoc', ns, ver, docToAdd]);
          }

          var docToRm = cache.shift();
          messages.push(['rmDoc', ns, ver, docToRm, docToRm.id]);
          return cb(null, messages);
        });
      case 'mv-curr->prior':
        return fetchSlice(json, 0, 2, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return debug(err);
          }

          var sanityDoc = docs[1]
            , docToAdd  = docs[0]
            , messages = []
            , isSane = deepEqual(sanityDoc, cache[0]);
          if (isSane) {
            if (-1 === indexOf(cache, docToAdd, equivIds)) {
              messages.push(['rmDoc', ns, ver, newDoc, newDoc.id]);
              messages.push(['addDoc', ns, ver, docToAdd]);
            } else { // This means the the mv is meant to be curr->curr
              messages.push(['txn']);
            }
            cache.splice(delta.from, 1);
            cache.unshift(docToAdd);
            return cb(null, messages);
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
        return cb(null, [['txn']]);
      case 'mv-curr->later':
        return fetchSlice(json, json.limit - 2, json.limit, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return debug(err);
          }

          var sanityCheck = docs[0]
            , docToAdd    = docs[1]
            , messages    = [];
          // TODO Replace strict equals with deepEquals
          if (docToAdd && deepEqual(sanityCheck, cache[cache.length - 1])) {
            cache.push(docToAdd);
            messages.push(['addDoc', ns, ver, docToAdd]);
          }

          cache.splice(delta.from, 1);
          messages.push(['rmDoc', ns, ver, newDoc, newDoc.id]);
          return cb(null, messages);
        });
      case 'mv-later->prior':
        return fetchSlice(json, 0, 2, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return debug(err);
          }

          var sanityCheck = docs[1]
            , docToAdd    = docs[0]
            , messages    = [];
          if (deepEqual(sanityCheck, cache[0])) {
            cache.unshift(docToAdd);
            messages.push(['addDoc', ns, ver, docToAdd]);
          }
          var docToRm = cache.pop();
          messages.push(['rmDoc', ns, ver, docToRm, docToRm.id]);
          return cb(null, messages);
        });
      case 'mv-later->curr':
        var messages = [];
        cache.splice(delta.to, 0, newDoc);
        messages.push(['addDoc', ns, ver, newDoc]);
        var docToRm = cache.pop();
        messages.push(['rmDoc', ns, ver, docToRm, docToRm.id]);
        return cb(null, messages);
      case 'mv-later->later': return cb(null, false);
      default: throw new Error();
    }
  }

  if (oldDocPasses && !newDocPasses) {
    switch (delta.from) {
      case Infinity: return cb(null, false);
      case -Infinity:
        return fetchSlice(json, json.limit - 2, json.limit, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return debug(err);
          }

          var sanityDoc = docs[0]
            , docToAdd  = docs[1]
            , messages  = [];
          if (docToAdd && deepEqual(sanityDoc, cache[cache.length-1])) {
            cache.push(docToAdd);
            messages.push(['addDoc', ns, ver, docToAdd]);
          }
          var docToRm = cache.shift();
          messages.push(['rmDoc', ns, ver, docToRm, docToRm.id]);
          return cb(null, messages);
        });
      default:
        return fetchSlice(json, json.limit - 2, json.limit, store._db, function (err, docs) {
          if (err) {
            if (cb) return cb(err);
            return debug(err);
          }

          cache.splice(delta.from, 1);

          var sanityDoc = docs[0]
            , docToAdd  = docs[1]
            , messages  = [];
          if (docToAdd && deepEqual(sanityDoc, cache[cache.length-1])) {
            cache.push(docToAdd);
            messages.push(['addDoc', ns, ver, docToAdd]);
          }
          messages.push(['rmDoc', ns, ver, newDoc, oldDoc.id]);
          return cb(null, messages);
        });
    }
  }

  if (!oldDocPasses && newDocPasses) {
    switch (delta.to) {
      case Infinity: return cb(null, false);
      case null:
      case -Infinity:

        var messages = [];

        // If we're on the first page, interpret -Infinity === delta.to to mean
        // that we should insert this at the beginning of the cache.
        if (skip === 0) {
          if (cache.length === json.limit) {
            var docToRm = cache.pop();
            messages.push(['rmDoc', ns, ver, docToRm, docToRm.id]);
          }
          cache.unshift(newDoc);
          messages.push(['addDoc', ns, ver, newDoc]);
          return cb(null, messages);
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
            return debug(err);
          }
          if (deepEqual(docs[1], cache[0])) {
            if (cache.length === json.limit) {
              var docToRm = cache.pop();
              // TODO Make sure docToRm is with the change
              messages.push(['rmDoc', ns, ver, docToRm, docToRm.id]);
            }
            cache.unshift(docs[0]);
            messages.push(['addDoc', ns, ver, docs[0]]);
            return cb(null, messages);
          }
        });

      default:
        var messages = [];
        if (cache.length === json.limit) {
          var docToRm = cache.pop();
          messages.push(['rmDoc', ns, ver, docToRm, docToRm.id]);
        }
        cacheInsert(cache, newDoc, delta.to);
        messages.push(['addDoc', ns, ver, newDoc]);
        return cb(null, messages);
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

  if (!comparator) return Infinity;

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
