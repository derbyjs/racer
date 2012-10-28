var QueryBuilder = require('./QueryBuilder')
  , queryTypes = require('./types')
  , pathUtils = require('../../path')
  , isSubPathOf = pathUtils.isSubPathOf
  , isImmediateChild = pathUtils.isImmediateChild
  , isGrandchild = pathUtils.isGrandchild
  , indexOf = require('../../util').indexOf
  ;

module.exports = setupQueryModelScope;

/**
 * Given a model, query, and the query's initial result(s), this function sets
 * up and returns a scoped model that is centered on a ref or refList that
 * embodies the query result(s) and updates those result(s) whenever a relevant
 * mutation should change the query result(s).
 *
 * @param {Model} model is the racer model
 * @param {MemoryQuery} memoryQuery or a TransformBuilder that has
 * MemoryQuery's syncRun interface
 * @param {[Object]|Object} initialResult is either an array of documents or a
 * single document that represents the initial result of the query over the
 * data currently loaded into the model.
 * @return {Model} a refList or ref scoped model that represents the query result(s)
 */
function setupQueryModelScope (model, memoryQuery, queryId, initialResult) {
  var type = queryTypes[memoryQuery.type];

  if (typeof initialResult !== 'undefined') {
    type.assignInitialResult(model, queryId, initialResult);
  }

  var scopedModel = type.createScopedModel(model, memoryQuery, queryId, initialResult);

  if (! model[queryId]) {
    var listener = createMutatorListener(model, scopedModel, memoryQuery, queryId);
    model.on('mutator', listener);

    model[queryId] = listener;
    // TODO: This is a total hack. Fix the initialization of filters in client
    // and prevent filters from generating multiple listeners
  }

  return scopedModel;
}

/**
 * Creates a listener of the 'mutator' event, for the type (e.g., findOne) of
 * query.
 * See the JSDocDoc of the function iniside the block to see what this listener
 * does.
 *
 * @param {Model} model is the racer model
 * @param {String} ns is the query namespace that points to the set of data we
 * wish to query
 * @param {Model} scopedModel is the scoped model that is scoped to the query
 * results
 * @param {Object} queryTuple is [ns, {queryMotif: queryArgs}, queryId]
 * @return {Function} a function to be used as a listener to the "mutator"
 * event emitted by model
 */
function createMutatorListener (model, scopedModel, memoryQuery, queryId) {
  var ns = memoryQuery.ns;

  // TODO Move this closer to MemoryQuery instantiation
  memoryQuery.id = queryId;

  /**
   * This function will listen to the "mutator" event emitted by the model. The
   * purpose of listening for "mutator" here is to respond to changes to the
   * set of documents that the relevant query scans over to derive its search
   * results. Hence, the mutations it listens for are mutations on its search
   * domain, where that domain can be an Object of documents or an Array of documents.
   *
   * Fires callbacks by analyzing how model[method](_arguments...) has affected a
   * query searching over the Tree or Array of documents pointed to by ns.
   *
   * @param {String} method name
   * @param {Arguments} _arguments are the arguments for a given "mutator" event listener.
   * The arguments have the signature [[path, restOfMutationArgs...], out, isLocal, pass]
   */

  return function (method, _arguments) {
    var args = _arguments[0]
      , out = _arguments[1]
      , path = args[0]

        // The documents this query searches over, either as an Array or Object of
        // documents. This set of documents reflects that the mutation has already
        // taken place.
      , searchSpace = model.get(ns)
      , queryType = queryTypes[memoryQuery.type]
      , currResult = scopedModel.get()
      ;

    if (currResult == null) currResult = queryType.resultDefault;

    // Ignore irrelevant paths. Because any mutation on any object causes model
    // to fire a "mutator" event, we will want to ignore most of these mutator
    // events because our listener is only concerned about mutations that
      // affect ns.
    if (! isSubPathOf(ns, path) && ! isSubPathOf(path, ns)) return;

//    if (isSubPathOf(path, ns)) {
//      if (!searchSpace) return;
//      return queryType.onOverwriteNs(searchSpace, memoryQuery, model);
//    }

    if (path === ns) {
      if (method === 'set') {
        return queryType.onOverwriteNs(searchSpace, memoryQuery, model);
      }

      if (method === 'del') {
        return queryType.onRemoveNs(searchSpace, memoryQuery, model);
      }

      if (method === 'push' || method === 'insert' || method === 'unshift') {
        var Model = model.constructor
          , docsToAdd = args[Model.arrayMutator[method].insertArgs];
        if (Array.isArray(docsToAdd)) {
          docsToAdd = docsToAdd.filter( function (doc) {
            // Ensure that the document is in the domain (it may not be if we are
            // filtering over some query results)
            return doesBelong(doc, searchSpace);
          });
          queryType.onInsertDocs(docsToAdd, memoryQuery, model, searchSpace, currResult);
        } else {
          var doc = docsToAdd;
          // TODO Is this conditional if redundant? Isn't this always true?
          if (doesBelong(doc, searchSpace)) {
            queryType.onInsertDocs([doc], memoryQuery, model, searchSpace, currResult);
          }
        }
        return;
      }

      if (method === 'pop' || method === 'shift' || method === 'remove') {
        var docsToRm = out;
        for (var i = 0, l = docsToRm.length; i < l; i++) {
          queryType.onRmDoc(docsToRm[i], memoryQuery, model, searchSpace, currResult);
        }
        return;
      }

      // TODO Is this the right logic for move?
      if (method === 'move') {
        var movedIds = out
          , onUpdateDocProperty = queryType.onUpdateDocProperty
          , docs = model.get(path);
          ;
        for (var i = 0, l = movedIds.length; i < l; i++) {
          var id = movedIds[i], doc;
          // TODO Ugh, this is messy
          if (Array.isArray(docs)) {
            doc = docs[indexOf(docs, id, equivId)];
          } else {
            doc = docs[id];
          }
          onUpdateDocProperty(doc, memoryQuery, model, searchSpace, currResult);
        }
        return;
      }
      throw new Error('Uncaught edge case');
    }

    // From here on: path = ns + suffix

    // The mutation can:
    if (isImmediateChild(ns, path)) {
      // (1) remove the document
      if (method === 'del') {
        return queryType.onRmDoc(out, memoryQuery, model, searchSpace, currResult);
      }

      // (2) add or over-write the document with a new version of the document
      if (method === 'set' || method === 'setNull') {
        var doc = args[1]
          , belongs = doesBelong(doc, searchSpace);
        if (! out) {
          return queryType.onAddDoc(doc, out, memoryQuery, model, searchSpace, currResult);
        }
        if (doc.id === out.id) {
          return queryType.onAddDoc(doc, out, memoryQuery, model, searchSpace, currResult);
        }
      }
      throw new Error('Uncaught edge case: ' + method + ' ' + require('util').inspect(_arguments, false, null));
    }

    if (isGrandchild(ns, path)) {
      var suffix = path.substring(ns.length + 1)
        , separatorPos = suffix.indexOf('.')
        , property = suffix.substring(0, ~separatorPos ? separatorPos : suffix.length)
        , isArray = Array.isArray(searchSpace)
        ;
      if (isArray) property = parseInt(property, 10);
      var doc = searchSpace && searchSpace[property];
      if (doc) queryType.onUpdateDocProperty(doc, memoryQuery, model, searchSpace, currResult);
    }
  };
}

function doesBelong (doc, searchSpace) {
  if (Array.isArray(searchSpace)) {
    return indexOf(searchSpace, doc.id, equivId) !== -1;
  }
  return doc.id in searchSpace;
}

function equivId (id, doc) {
  return doc && doc.id === id;
}
