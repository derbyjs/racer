var PRIVATE_COLLECTION = require('./constants').PRIVATE_COLLECTION
var isSpeculative = require('../../../util/speculative').isSpeculative;
exports.exec = function (matches, memoryQuery) {
  if (Array.isArray(matches)) {
    return matches.length
  }
  return Object.keys(matches).length;
};

exports.assignInitialResult = function (model, queryId, initialResult) {
  model.set(getResultPath(queryId), initialResult || 0);
};

exports.createScopedModel = function (model, memoryQuery, queryId) {
  var ns = memoryQuery.ns
  return model.at(getResultPath(queryId));
};

function getResultPath (queryId) {
  return PRIVATE_COLLECTION + '.' + queryId + '.count';
}

exports.onOverwriteNs = function (docs, countQuery, model) {
  var queryId = countQuery.id
    , count = countQuery.syncRun(docs);
  model.set(getResultPath(queryId), count);
};

exports.onRemoveNs = function (docs, countQuery, model) {
  model.set(getResultPath(countQuery.id), 0);
};

exports.onAddDoc = function (newDoc, oldDoc, countQuery, model, searchSpace, currResult) {
  var ns = countQuery.ns
    , doesBelong = countQuery.filterTest(newDoc, ns);
  if (! doesBelong) return;

  var resultPath = getResultPath(countQuery.id);
  model.set(resultPath, (currResult || 0) + 1);
};

exports.onInsertDocs = function (newDocs, countQuery, model, searchSpace, currResult) {
  var belongCount = 0;

  for (var i = 0; i < newDocs.length; i++) 
    if (countQuery.filterTest(newDocs[i]))
      belongCount++;

  var resultPath = getResultPath(countQuery.id);
  model.set(resultPath, currResult + belongCount);
};

exports.onRmDoc = function (oldDoc, countQuery, model, searchSpace, currResult) {
  var ns = countQuery.ns
    , doesBelong = countQuery.filterTest(oldDoc, ns);
  if (! doesBelong) return;

  var resultPath = getResultPath(countQuery.id);
  model.set(resultPath, currResult - 1);
};

exports.onUpdateDocProperty = function (doc, countQuery, model, searchSpace, currResult) {
  var ns = countQuery.ns
    , resultPath = getResultPath(countQuery.id);

  if (!isSpeculative(doc)) {
    model.set(resultPath, countQuery.syncRun(searchSpace));
    return;
  }
  // If the doc is a speculative change
  // of the base model, we can check if
  // the new and old values are matched
  // by the query, and update the count
  var didBelong = countQuery.filterTest(Object.getPrototypeOf(doc), ns)
    , doesBelong = countQuery.filterTest(doc, ns)

  if (didBelong === doesBelong) // This change did not affect the query
    return;

  if (doesBelong)
    model.set(resultPath, currResult + 1);
  else
    model.set(resultPath, currResult - 1);
};

exports.resultDefault = 0;
