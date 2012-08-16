var sortUtils = require('../../../computed/sort')
  , sortDomain = sortUtils.sortDomain
  , projectDomain = require('../../../computed/project').projectDomain
  , sliceDomain = require('../../../computed/range').sliceDomain
  , PRIVATE_COLLECTION = require('./constants').PRIVATE_COLLECTION
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

  // Truncate to limit the work of the subsequent field projections step.
  matches = [matches[0]];

  // Selectively return the documents with a subset of fields based on
  // `except` or `only`
  var only = memoryQuery._only
    , except = memoryQuery._except;
  if (only || except) {
    matches = projectDomain(matches, only || except, !!except);
  }

  return matches[0];
};

exports.assignInitialResult = function (model, queryId, initialResult) {
  if (!initialResult) return;
  model.set(getPointerPath(queryId), initialResult.id);
};

exports.createScopedModel = function (model, memoryQuery, queryId) {
  var ns = memoryQuery.ns
  return model.ref(refPath(queryId), ns, getPointerPath(queryId));
};

function refPath (queryId) {
  return PRIVATE_COLLECTION + '.' + queryId + '.result';
}

function getPointerPath (queryId) {
  return PRIVATE_COLLECTION + '.' + queryId + '.resultId';
}

// In this case, docs is the same as searchSpace.
exports.onOverwriteNs = function (docs, findOneQuery, model) {
  var queryId = findOneQuery.id
    , findQuery = equivFindQuery(findOneQuery);
  docs = findQuery.syncRun(docs);
  model.set(getPointerPath(queryId), docs[0].id);
};

exports.onRemoveNs = function (docs, findOneQuery, model) {
  var queryId = findOneQuery.id;
  model.del(getPointerPath(queryId));
};

// TODO Think through this logic more
exports.onAddDoc = function (newDoc, oldDoc, findOneQuery, model, searchSpace, currResult) {
  var ns = findOneQuery.ns
    , doesBelong = findOneQuery.filterTest(newDoc, ns);
  if (! doesBelong) return;
  var pointerPath = getPointerPath(findOneQuery.id);
  if (currResult) {
    var list = [currResult, newDoc];
    if (list.length === 2) {
      var comparator = findOneQuery._comparator;
      list = list.sort(comparator);
      model.set(pointerPath, list[0].id);
    }
  } else {
    model.set(pointerPath, newDoc.id);
  }
};

exports.onInsertDocs = function (newDocs, findOneQuery, model, searchSpace, currResult) {
  var list = (currResult) ? [currResult].concat(newDocs) : newDocs
    , comparator = findOneQuery._comparator
    ;
  list = list.sort(comparator);
  var pointerPath = getPointerPath(findOneQuery.id);
  model.set(pointerPath, list[0].id);
};

exports.onRmDoc = function (oldDoc, findOneQuery, model, searchSpace, currResult) {
  if (oldDoc.id === (currResult && currResult.id)) {
    var findQuery = equivFindQuery(findOneQuery)
      , results = equivFindQuery.syncRun(searchSpace);
    if (!results.length) return;
    var pointerPath = getPointerPath(findOneQuery.id);
    model.set(pointerPath, results[0].id);
  }
};

exports.onUpdateDocProperty = function (doc, memoryQuery, model, searchSpace, currResult) {
  var ns = memoryQuery.ns
    , pointerPath = getPointerPath(memoryQuery.id);

  if (!memoryQuery.filterTest(doc, ns)) {
    if ((currResult && currResult.id) !== doc.id) return;
    var results = equivFindQuery(memoryQuery).syncRun(searchSpace)
    if (results.length) {
      return model.set(pointerPath, results[0].id);
    }
    return model.set(pointerPath, null);
  }
  var comparator = memoryQuery._comparator;
  if (!comparator) {
    return model.set(pointerPath, doc.id);
  }
  if (comparator(doc, currResult) < 0) {
    model.set(pointerPath, doc.id);
  }
};

function equivFindQuery (findOneQuery) {
  var MemoryQuery = findOneQuery.constructor;
  return new MemoryQuery(Object.create(findOneQuery.toJSON(), {
    type: { value: 'find' }
  }));
}
