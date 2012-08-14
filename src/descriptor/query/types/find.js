var sortUtils = require('../../../computed/sort')
  , sortDomain = sortUtils.sortDomain
  , projectDomain = require('../../../computed/project').projectDomain
  , sliceDomain = require('../../../computed/range').sliceDomain
  , PRIVATE_COLLECTION = require('./constants').PRIVATE_COLLECTION
  , indexOf = require('../../../util').indexOf
  ;

exports.exec = function (matches, memoryQuery) {
  // Query results should always be a list. sort co-erces the results into a
  // list even if comparator is not present.
  matches = sortDomain(matches, memoryQuery._comparator);

  // Handle skip/limit for pagination
  var skip = memoryQuery._skip
    , limit = memoryQuery._limit;
  if (typeof limit !== 'undefined') {
    matches = sliceDomain(matches, skip, limit);
  }

  // Selectively return the documents with a subset of fields based on
  // `except` or `only`
  var only = memoryQuery._only
    , except = memoryQuery._except;
  if (only || except) {
    matches = projectDomain(matches, only || except, !!except);
  }

  return matches;
};

exports.assignInitialResult = function (model, queryId, initialResult) {
  if (!initialResult) return model.set(getPointerPath(queryId), []);
  var ids = [];
  for (var i = 0, l = initialResult.length; i < l; i++) {
    ids.push(initialResult[i].id);
  }
  model.set(getPointerPath(queryId), ids);
};

exports.createScopedModel = function (model, memoryQuery, queryId, initialResult) {
  var ns = memoryQuery.ns;
  return model.refList(refPath(queryId), ns, getPointerPath(queryId));
};

function refPath (queryId) {
  return PRIVATE_COLLECTION + '.' + queryId + '.results';
}

function getPointerPath (queryId) {
  return PRIVATE_COLLECTION + '.' + queryId + '.resultIds'
}

// All of these callbacks are semantically relative to our search
// space. Hence, onAddDoc means a listener for the event when a
// document is added to the search space to query.

// In this case, docs is the same as searchSpace.
exports.onOverwriteNs = function (docs, findQuery, model) {
  var docs = findQuery.syncRun(docs)
    , queryId = findQuery.id
  model.set(getPointerPath(queryId), docs);
};

exports.onRemoveNs = function (model, findQuery, model) {
  var queryId = findQuery.id;
  model.set(getPointerPath(queryId), []);
};

exports.onReplaceDoc = function (newDoc, oldDoc) {
  return onUpdateDocProperty(newDoc);
}

exports.onAddDoc = function (newDoc, oldDoc, memoryQuery, model, searchSpace, currResult) {
  var ns = memoryQuery.ns
    , doesBelong = memoryQuery.filterTest(newDoc, ns)
    ;
  if (! doesBelong) return;

  var pointerPath = getPointerPath(memoryQuery.id)
    , pointers = model.get(pointerPath)
    , alreadyAResult = (pointers && (-1 !== pointers.indexOf(newDoc.id)));
  if (alreadyAResult) return;

  if (memoryQuery.isPaginated && currResult.length === memoryQuery._limit) {
    // TODO Re-do this hack later
    return;
  }
  insertDocAsPointer(memoryQuery._comparator, model, pointerPath, currResult, newDoc);
};

exports.onInsertDocs = function (newDocs, memoryQuery, model, searchSpace, currResult) {
  for (var i = 0, l = newDocs.length; i < l; i++) {
    this.onAddDoc(newDocs[i], null, memoryQuery, model, searchSpace, currResult);
  }
};

exports.onRmDoc = function (oldDoc, memoryQuery, model) {
  // If the doc is no longer in our data, but our results have a reference to
  // it, then remove the reference to the doc.
  if (!oldDoc) return;
  var queryId = memoryQuery.id
    , pointerPath = getPointerPath(queryId)
  var pos = model.get(pointerPath).indexOf(oldDoc.id);
  if (~pos) model.remove(pointerPath, pos, 1);
};

exports.onUpdateDocProperty = function (doc, memoryQuery, model, searchSpace, currResult) {
  var id = doc.id
    , ns = memoryQuery.ns
    , queryId = memoryQuery.id
    , pointerPath = getPointerPath(queryId)
    , currPointers = model.get(pointerPath) || []
    , pos = currPointers.indexOf(id);

  // If the updated doc belongs in our query results...
  if (memoryQuery.filterTest(doc, ns)) {
    // ...and it is already recorded in our query result.
    if (~pos) {
      // Then, figure out if we need to re-order our results
      var resortedResults = currResult.sort(memoryQuery._comparator)
        , newPos = indexOf(resortedResults, id, equivId);
      if (pos === newPos) return;
      return model.move(pointerPath, pos, newPos, 1);
    }

    // ...or it is not recorded in our query result
    if (memoryQuery.isPaginated && currResult.length === memoryQuery._limit) {
      // TODO Re-do this hack later
      return;
    }
    return insertDocAsPointer(memoryQuery._comparator, model, pointerPath, currResult, doc);
  }

  // Otherwise, if the doc does not belong in our query results, but
  // it did belong to our query results prior to mutation...
  if (~pos) model.remove(pointerPath, pos, 1);
};

exports.resultDefault = [];

/**
 * @param {Function} comparator is the sort comparator function of the query
 * @param {Model} model is the racer model
 * @param {String} pointerPath is the path where the list of pointers (i.e.,
 * document ids) to documents resides
 * @param {[Object]} currResults is the array of documents representing the
 * results as cached prior to the mutation.
 * @param {Object} doc is the document we want to insert into our query results
 */
function insertDocAsPointer (comparator, model, pointerPath, currResults, doc) {
  if (!comparator) {
    var lastResult = currResults[currResults.length-1];
    if (lastResult && lastResult.id === doc.id) return;
    var out = model.insert(pointerPath, currResults.length, doc.id);
    return out;
  }
  for (var k = currResults.length; k--; ) {
    var currRes = currResults[k]
      , comparison = comparator(doc, currRes);
    if (comparison >= 0) {
      if (doc.id === currRes.id) return;
      return model.insert(pointerPath, k+1, doc.id);
    }
  }
  return model.insert(pointerPath, 0, doc.id);
}

function equivId (id, doc) {
  return doc && doc.id === id;
}
