var QueryBuilder = require('./QueryBuilder')
  , PRIVATE_COLLECTION = '_$queries';

exports.resultPointerPath = resultPointerPath;
exports.setupQueryModelScope = setupQueryModelScope;

function privateQueryPath (queryJson, pathSuffix) {
  var queryHash = QueryBuilder.hash(queryJson)
    , path = PRIVATE_COLLECTION + '.' + queryHash;
  if (pathSuffix) path += '.' + pathSuffix;
  return path;
}

function resultPointerPath (queryJson) {
  var pathSuffix = (queryJson.type === 'findOne')
                 ? 'resultId'
                 : 'resultIds';
  return privateQueryPath(queryJson, pathSuffix);
}

function resultRefPath (queryJson) {
  var pathSuffix = (queryJson.type === 'findOne')
                 ? 'result'
                 : 'results';
  return privateQueryPath(queryJson, pathSuffix);
}

function setupQueryModelScope (model, queryJson, initialResult) {
  var refPath = resultRefPath(queryJson)
    , pointerPath = resultPointerPath(queryJson)
    , ns = queryJson.from
    , scopedModel;

  // Refs, assemble!
  switch (queryJson.type) {
    case 'findOne':
      // TODO Test findOne single query result
      scopedModel = model.ref(refPath, ns, pointerPath);
      break;

    case 'find':
    default:
      if (initialResult) {
        model.set(pointerPath, initialResult.map( function (doc) {
          return doc.id;
        }));
      }
      scopedModel = model.refList(refPath, ns, pointerPath);
      var listener = createMutatorListener(model, pointerPath, ns, scopedModel, queryJson);

      model.on('mutator', listener);
      break;
  }
  return scopedModel;
}

function createMutatorListener (model, pointerPath, ns, scopedModel, queryJson) {
  return function (method, _arguments) {
    var args = _arguments[0]
      , path = args[0];
    if (ns !== path.substring(0, path.indexOf('.'))) return;

    var id = path.split('.')[1]
      , docPath = ns + '.' + id
      , doc = model.get(docPath)
      , pos = model.get(pointerPath).indexOf(id);

    if (!doc && ~pos) return model.remove(pointerPath, pos, 1);

    var currResults = scopedModel.get()
      , memoryQuery = model.locateQuery(queryJson);
    if (memoryQuery.filterTest(doc, ns)) {
      if (~pos) return;
      var comparator = memoryQuery._comparator;
      if (!comparator) {
        return model.insert(pointerPath, currResults.length, doc.id);
      }
      for (var k = currResults.length; k--; ) {
        var currRes = currResults[k];
        var comparison = comparator(doc, currRes);
        if (comparison >= 0) {
          return model.insert(pointerPath, k+1, doc.id);
        }
      }
      return model.insert(pointerPath, 0, doc.id);
    } else {
      if (~pos) model.remove(pointerPath, pos, 1);
    }
  };
}

