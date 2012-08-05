var PRIVATE_COLLECTION = require('./constants').PRIVATE_COLLECTION
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
  var queryId = findOneQuery.id
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
  model.set(pointerPath, currResult + newDocs.length);
};

exports.onRmDoc = function (oldDoc, countQuery, model, searchSpace, currResult) {
  var ns = countQuery.ns
    , doesBelong = countQuery.filterTest(oldDoc, ns);
  if (! doesBelong) return;
  var resultPath = getResultPath(countQuery.id);
  model.set(resultPath, currResult - 1);
};

exports.onUpdateDocProperty = function (doc, countQuery, model, searchSpace, currResult) {
  var resultPath = getResultPath(countQuery.id)
    , count = countQuery.syncRun(searchSpace);
  model.set(resultPath, count);
};

exports.resultDefault = 0;
