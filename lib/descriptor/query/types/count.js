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
  return; // TODO Figure out how best to handle count later

  var queryId = findOneQuery.id
    , count = countQuery.syncRun(docs);
  model.set(getResultPath(queryId), count);
};

exports.onRemoveNs = function (docs, countQuery, model) {
  model.set(getResultPath(countQuery.id), 0);
};

exports.onAddDoc = function (newDoc, oldDoc, countQuery, model, searchSpace, currResult) {
  return; // TODO Figure out how best to handle count later

  var ns = countQuery.ns
    , doesBelong = countQuery.filterTest(newDoc, ns);
  if (! doesBelong) return;
  var resultPath = getResultPath(countQuery.id);
  console.log(currResult)
  model.set(resultPath, (currResult || 0) + 1);
};

exports.onInsertDocs = function (newDocs, countQuery, model, searchSpace, currResult) {
  return; // TODO Figure out how best to handle count later

  model.set(pointerPath, currResult + newDocs.length);
};

exports.onRmDoc = function (oldDoc, countQuery, model, searchSpace, currResult) {
  return; // TODO Figure out how best to handle count later

  var ns = countQuery.ns
    , doesBelong = countQuery.filterTest(oldDoc, ns);
  if (! doesBelong) return;
  var resultPath = getResultPath(countQuery.id);
  model.set(resultPath, currResult - 1);
};

exports.onUpdateDocProperty = function (doc, countQuery, model, searchSpace, currResult) {
  return; // TODO Figure out how best to handle count later
  var resultPath = getResultPath(countQuery.id)
    , count = countQuery.syncRun(searchSpace);
  model.set(resultPath, count);
};

exports.resultDefault = 0;
