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

function isPrefixOf (prefix, path) {
  return path.substring(0, prefix.length) === prefix;
}

function createMutatorListener (model, pointerPath, ns, scopedModel, queryJson) {
  return function (method, _arguments) {
    var args = _arguments[0]
      , path = args[0]
      , doc;

    if (! isPrefixOf(ns, path)) return;

    // Handle special edge case of when what we are querying over is an array
    // of documents (e.g., this is the case for query results)
    var arrayMutators = model.constructor.arrayMutator;
    if (method in arrayMutators) {
          // The documents this query searches over, either as an Array
          // or Object of documents. This set of documents reflects that the
          // mutation has already taken place.
      var searchSpace = model.get(path)

          // List of document ids that match the query, as cached before the
          // mutation
        , pointers = model.get(pointerPath)

          // Maintain a list of document ids, starting off as the pointer list.
          // As we evaluate the updated search space against the query and the
          // query result cache via pointers, we remove the evaluated id's from
          // remaining. After exhausting the search space, the documents left
          // in remaining -- if any -- are documents that were in the result
          // set prior to the mutation but that must be removed because the
          // mutation removed that document from the search space, and we can
          // only include results from the search space.
        , remaining = pointers.slice();

      for (var i = 0, l = searchSpace.length; i < l; i++) {
        var currDoc = searchSpace[i]
          , currId = currDoc.id
          , pos = pointers.indexOf(currId);
        if (~pos) {
          remaining.splice(remaining.indexOf(currId), 1);
          if (! memoryQuery.filterTest(currDoc, ns)) {
            model.remove(pointerPath, pos, 1);
          }
        } else {
          var memoryQuery = model.locateQuery(queryJson)
            , currResults = scopedModel.get();
          if (memoryQuery.filterTest(currDoc, ns)) {
            insertDocAsPointer(memoryQuery._comparator, model, pointerPath, currResults, currDoc);
          }
        }
      }
      // Anything remaining is obviously not in the searchSpace, so we should
      // remove it from our pointers
      for (i = 0, l = remaining.length; i < l; i++) {
        pos = pointers.indexOf(remaining[i]);
        model.remove(pointerPath, pos, 1);
      }
      return;
    }

    var id = path.split('.')[1];
    doc = model.get(ns + '.' + id);

    var pos = model.get(pointerPath).indexOf(id);

    // If the doc is no longer in our data, but our results have a reference to
    // it, then remove the reference to the doc.
    if (!doc && ~pos) return model.remove(pointerPath, pos, 1);

    var currResults = scopedModel.get()
      , memoryQuery = model.locateQuery(queryJson);
    if (memoryQuery.filterTest(doc, ns)) {
      if (~pos) return;
      return insertDocAsPointer(memoryQuery._comparator, model, pointerPath, currResults, doc);
    } else {
      if (~pos) model.remove(pointerPath, pos, 1);
    }
  };
}

function insertDocAsPointer (comparator, model, pointerPath, currResults, doc) {
      if (!comparator) {
        return model.insert(pointerPath, currResults.length, doc.id);
      }
      for (var k = currResults.length; k--; ) {
        var currRes = currResults[k]
          , comparison = comparator(doc, currRes);
        if (comparison >= 0) {
          return model.insert(pointerPath, k+1, doc.id);
        }
      }
      return model.insert(pointerPath, 0, doc.id);
}
