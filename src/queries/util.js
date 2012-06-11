var QueryBuilder = require('./QueryBuilder')
  , MemoryQuery = require('./MemoryQuery')
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
      if (initialResult) {
        model.set(pointerPath, initialResult.id);
      }

      scopedModel = model.ref(refPath, ns, pointerPath);

      var listener = createMutatorListener(model, pointerPath, ns, scopedModel, queryJson);
      model.on('mutator', listener);
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
  }
  return scopedModel;
}

function isPrefixOf (prefix, path) {
  return path.substring(0, prefix.length) === prefix;
}

// TODO Re-factor createMutatorListener
/**
 * @param {Model} model
 * @param {String} pointerPath is the path to the refList key
 * @param {String} ns is the query namespace that points to the set of data we
 * wish to query
 * @param {Model} scopedModel is the scoped model that is scoped to the query
 * results
 * @param {Object} queryJson is the json representation of the query
 * @return {Function} a function to be used as a listener to the "mutator"
 * event emitted by model
 */
function createMutatorListener (model, pointerPath, ns, scopedModel, queryJson) {
  /**
   * This function will listen to the "mutator" event emitted by the model. The
   * purpose of listening for "mutator" here is to respond to changes to the
   * set of documents that the relevant query queries over to derive its search
   * results. Hence, the mutations it listens for are mutations on its search
   * domain, where that domain can be an Object of documents or an Array of documents.
   *
   * @param {String} method name
   * @param {Arguments} _arguments are the arguments for a given "mutator" event listener.
   * The arguments have the signature [[path, restOfMutationArgs...], out, isLocal, pass]
   */
  return function (method, _arguments) {
    var path = _arguments[0][0];

    // Ignore any irrelevant paths. Because any mutation on any object causes
    // model to fire a "mutator" event, we will want to ignore most of these
    // mutator events because our listener is only concerned about mutations
    // under ns, i.e., under our search domain.
    if (! isPrefixOf(ns, path)) return;

    // From here on:  path = ns + suffix

    var currResult = scopedModel.get()
      , memoryQuery = model.locateQuery(queryJson);

    var arrayMutators = model.constructor.arrayMutator;
    if (method in arrayMutators) {
      handleQueryOverDocArray(memoryQuery, model, path, pointerPath, currResult, ns);
    } else {
      handleQueryOverDocTree(memoryQuery, model, path, pointerPath, currResult, ns);
    }

  };
}

// Case 1: Handle when our query is over an array of documents
function handleQueryOverDocArray (memoryQuery, model, path, pointerPath, currResult, ns) {
      // The documents this query searches over, either as an Array
      // or Object of documents. This set of documents reflects that the
      // mutation has already taken place.
  var searchSpace = model.get(ns);

  switch (memoryQuery._type) {
    case 'find':
      // List of document ids that match the query, as cached before the mutation
      var pointers = model.get(pointerPath)

      // Maintain a list of document ids, starting off as the pointer list.
      // As we evaluate the updated search space against the query and the
      // query result cache via pointers, we remove the evaluated id's from
      // remaining. After exhausting the search space, the documents left
      // in remaining -- if any -- are documents that were in the result
      // set prior to the mutation but that must be removed because the
      // mutation removed that document from the search space, and we can
      // only include results from the search space.
        , remaining = pointers.slice()

        , pos;

      // Update the pointer list of results by evaluating each document in the
      // search space against the current pointer list and the query. This loop
      // also clears out any pointers in the pointer list that no longer point
      // to a document because the document has been removed from the search space.
      for (var i = 0, l = searchSpace.length; i < l; i++) {
        var currDoc = searchSpace[i]
          , currId = currDoc.id;
        pos = pointers.indexOf(currId);
        if (~pos) {
          remaining.splice(remaining.indexOf(currId), 1);
          if (! memoryQuery.filterTest(currDoc, ns)) {
            model.remove(pointerPath, pos, 1);
          }
        } else {
          if (memoryQuery.filterTest(currDoc, ns)) {
            insertDocAsPointer(memoryQuery._comparator, model, pointerPath, currResult, currDoc);
          }
        }
      }
      // Anything remaining is obviously not in the searchSpace, so we should
      // remove it from our pointers
      for (i = 0, l = remaining.length; i < l; i++) {
        pos = pointers.indexOf(remaining[i]);
        model.remove(pointerPath, pos, 1);
      }
      break;

    case 'findOne':
      return maybeUpdateFindOnePointer(pointerPath, model, memoryQuery, ns, currResult);
    default:
      throw new TypeError();
  }
}

// Case 2: Handle when our query is over an Object of documents
function handleQueryOverDocTree (memoryQuery, model, path, pointerPath, currResult, ns) {
  // `path` is the location of data on which the mutation acted. It could be on
  // the level of the document or on a nested part of the document we are
  // interested in. Whatever the case, extract the document of interest.
  var suffix = path.substring(ns.length + 1)
    , separatorPos = suffix.indexOf('.')
    , id = suffix.substring(0, ~separatorPos ? separatorPos : suffix.length)
    , doc = model.get(ns + '.' + id);

  switch (memoryQuery._type) {
    case 'find':
      // Is the  document already in our result set?
      var pos = model.get(pointerPath).indexOf(id);

      // If the doc is no longer in our data, but our results have a reference to
      // it, then remove the reference to the doc.
      if (!doc && ~pos) return model.remove(pointerPath, pos, 1);

      // If the doc belongs in our query results...
      if (memoryQuery.filterTest(doc, ns)) {
        // ...and it is already recorded in our query result.
        if (~pos) return;

        // ...or it is not recorded in our query result.
        insertDocAsPointer(memoryQuery._comparator, model, pointerPath, currResult, doc);

      // Otherwise, if the doc does not belong in our query results, but it did
      // belong to our query results prior to the mutation...
      } else if (~pos) {
        model.remove(pointerPath, pos, 1);
      }
      break;
    case 'findOne':
      // Because re-ordering a result set can change the findOne result, we
      // should compare the updated document to the currently cached result.

      var comparator = memoryQuery._comparator;

      // If we updated a document that is our current cached result...
      if (currResult && currResult.id === id) {
        // TODO We can be more efficient here if we only deal with our before
        // and after updated doc, and use comparator on them.

        return maybeUpdateFindOnePointer(pointerPath, model, memoryQuery, ns, currResult);

      // If we updated a document different than our currently cached result...
      } else {
        // Then check where the updated doc should be positioned relative to
        // our cached result.
        var comparison = comparator(doc, currResult);

        // If later, then do not update our cached result.
        if (comparison >= 0) return;

        // Otherwise, make the updated doc our new findOne cached result
        return model.set(pointerPath, doc.id);
      }
      break;
    default:
      throw new TypeError();
  }
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

function maybeUpdateFindOnePointer (pointerPath, model, memoryQuery, ns, currResult) {
  var equivFindQuery = new MemoryQuery(Object.create(memoryQuery.toJSON(), {
        type: { value: 'find' }
      }))

  // If so, we need to see if a document that would have been in an
  // equivalent find query is now positioned before the cached result.
    , searchSpace = model.get(ns)
    , results = equivFindQuery.syncRun(searchSpace);
  if (!results[0] || !currResult || results[0].id === currResult.id) return;
  return model.set(pointerPath, results[0].id);
}
