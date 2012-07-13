var QueryBuilder = require('./QueryBuilder')
  , MemoryQuery = require('./MemoryQuery')
  , indexOf = require('../util').indexOf
  , PRIVATE_COLLECTION = '_$queries'
  , EventEmitter = require('events').EventEmitter
  , pathUtils = require('../path')
  , splitPath = pathUtils.split
  , expandPath = pathUtils.expand
  ;

module.exports = {
  resultPointerPath: resultPointerPath
, setupQueryModelScope: setupQueryModelScope
, compileTargets: compileTargets
};


function resultPointerPath (queryId, queryType) {
  var pathSuffix = (queryType === 'findOne')
                 ? 'resultId'
                 : 'resultIds';
  return PRIVATE_COLLECTION + '.' + queryId + '.' + pathSuffix;
}

function resultRefPath (queryId, queryType) {
  var pathSuffix = (queryType === 'findOne')
                 ? 'result'
                 : 'results';
  return PRIVATE_COLLECTION + '.' + queryId + '.' + pathSuffix;
}

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
  var queryType = memoryQuery.type
    , refPath = resultRefPath(queryId, queryType)
    , pointerPath = resultPointerPath(queryId, queryType)
    , ns = memoryQuery.ns
    , scopedModel, listener;

  // Refs, assemble!
  if (queryType === 'findOne') {
    // TODO Test findOne single query result
    if (initialResult) {
      model.set(pointerPath, initialResult.id);
    }
    scopedModel = model.ref(refPath, ns, pointerPath);

  } else {
    if (initialResult) {
      model.set(pointerPath, initialResult.map( function (doc) {
        return doc.id;
      }));
    }
    scopedModel = model.refList(refPath, ns, pointerPath);
  }

  if (! model[refPath]) {
    listener = createMutatorListener(model, pointerPath, ns, scopedModel, memoryQuery);
    model.on('mutator', listener);

    // TODO: This is a total hack. Fix the initialization of filters in client
    // and prevent filters from generating multiple listeners
    model[refPath] = listener;
  }

  return scopedModel;
}

/**
 * Returns true if `prefix` is a prefix of `path`. Otherwise, returns false.
 * @param {String} prefix
 * @param {String} path
 * @return {Boolean}
 */
function isPrefixOf (prefix, path) {
  return path.substring(0, prefix.length) === prefix;
}

// TODO Re-factor createMutatorListener
/**
 * Creates a listener of the 'mutator' event, for find and findOne queries.
 * See the JSDocDoc of the function iniside the block to see what this listener
 * does.
 *
 * @param {Model} model is the racer model
 * @param {String} pointerPath is the path to the refList key
 * @param {String} ns is the query namespace that points to the set of data we
 * wish to query
 * @param {Model} scopedModel is the scoped model that is scoped to the query
 * results
 * @param {Object} queryTuple is [ns, {queryMotif: queryArgs}, queryId]
 * @return {Function} a function to be used as a listener to the "mutator"
 * event emitted by model
 */
function createMutatorListener (model, pointerPath, ns, scopedModel, memoryQuery, queryId) {
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
    var path = _arguments[0][0]
      , onAddDoc, onOverwriteNs, currResult;

    if (memoryQuery.type === 'findOne') {
      currResult = scopedModel.get();
      onOverwriteNs = function (docs) {
        var results = equivFindQuery.syncRun(docs);
        if (results.length) {
          model.set(pointerPath, results[0]);
        } else {
          model.set(pointerPath, null);
        }
      };
    } else {
      currResult = scopedModel.get() || [];
      onOverwriteNs = function (docs, each) {
        model.set(pointerPath, []);
        each(docs, function (doc) {
          if (memoryQuery.filterTest(doc, ns)) onAddDoc(doc);
        });
      };
      onAddDoc = function (newDoc, oldDoc) {
        if (!oldDoc) {
          // If the new doc belongs in our query results...
          if (memoryQuery.filterTest(newDoc, ns)) {
            insertDocAsPointer(memoryQuery._comparator, model, pointerPath, currResult, newDoc);
          }

        // Otherwise, we are over-writing oldDoc with newDoc
        } else {
          callbacks.onUpdateDocProperty(newDoc);
        }
      };

    }

    // Ignore any irrelevant paths. Because any mutation on any object causes
    // model to fire a "mutator" event, we will want to ignore most of these
    // mutator events because our listener is only concerned about mutations
    // under ns, i.e., under our search domain.
    if (! isPrefixOf(ns, path)) {
      if (isPrefixOf(path, ns)) {
        var domain = model.get(ns)
        if (!domain) return;
        var iterator = (Array.isArray(domain))
           ? function (docs, cb) {
               for (var i = 0, l = docs.length; i < l; i++) cb(docs[i]);
             }
           : function (docs, cb) {
               for (var k in docs) cb(docs[k]);
             }
        //handleMutation(model, method, ns, [ns, domain], null, ns, callbacks);
        onOverwriteNs(domain, iterator);
      }
      return;
    }

    // From here on:  path = ns + suffix


    // The documents this query searches over, either as an Array or Object of
    // documents. This set of documents reflects that the mutation has already
    // taken place.
    var searchSpace = model.get(ns);

    var callbacks;
    switch (memoryQuery.type) {
      case 'find':
        // All of these callbacks are semantically relative to our search
        // space. Hence, onAddDoc means a listener for the event when a
        // document is added to the search space to query.
        callbacks = {
          onRemoveNs: function () {
            model.set(pointerPath, []);
          }

          // TODO Deal with either array of docs or tree of docs
        , onOverwriteNs: onOverwriteNs

        , onAddDoc: onAddDoc

        , onRmDoc: function (oldDoc) {
            // If the doc is no longer in our data, but our results have a reference to
            // it, then remove the reference to the doc.
            var pos = model.get(pointerPath).indexOf(oldDoc.id);
            if (~pos) model.remove(pointerPath, pos, 1);
          }

        , onUpdateDocProperty: function (doc) {
            var id = doc.id
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
              return insertDocAsPointer(memoryQuery._comparator, model, pointerPath, currResult, doc);
            }

            // Otherwise, if the doc does not belong in our query results, but
            // it did belong to our query results prior to mutation...
            if (~pos) model.remove(pointerPath, pos, 1);
          }
        };
        break;
      case 'findOne':
        var equivFindQuery = new MemoryQuery(Object.create(memoryQuery.toJSON(), {
              type: { value: 'find' }
            }))
          , docsAdded = [currResult];

        callbacks = {
          onRemoveNs: function () {
            model.set(pointerPath, null);
          }

          // In this case, docs is the same as searchSpace.
        , onOverwriteNs: onOverwriteNs

        , onAddDoc: function (newDoc, oldDoc) {
            docsAdded.push(newDoc);
          }

        , onRmDoc: function (oldDoc) {
            if (oldDoc.id === (currResult && currResult.id)) {
              var results = equivFindQuery.syncRun(searchSpace);
              if (!results.length) return;
              model.set(pointerPath, results[0].id);
            }
          }

        , onUpdateDocProperty: function (doc) {
            if (!memoryQuery.filterTest(doc, ns)) {
              if ((currResult && currResult.id) !== doc.id) return;
              var results = equivFindQuery.syncRun(searchSpace);
              if (results.length) {
                return model.set(pointerPath, results[0].id);
              }
              return model.set(pointerPath, null);
            }
            var comparator = memoryQuery._comparator;
            if (!comparator) return;
            if (comparator(doc, currResult) < 0) {
              model.set(pointerPath, doc.id);
            }
          }

        , done: function () {
            if (docsAdded.length > 1) {
              docsAdded = docsAdded.sort(memoryQuery._comparator);
              model.set(pointerPath, docsAdded[0].id);
            }
          }
        };
        break;

      default:
        throw new TypeError();
    }

    var isSearchOverArray = Array.isArray(searchSpace);
    var handleMutation = (isSearchOverArray)
                       ? handleDocArrayMutation
                       : handleDocTreeMutation;

    handleMutation(model, method, _arguments, ns, searchSpace, callbacks);
  };
}

/**
 * Fires callbacks by analyzing how model[method](_arguments...) has affected
 * a query searching over the Array of documents pointed to by ns.
 * @param {Model} model
 * @param {String} method
 * @param {Arguments} _arguments
 * @param {String} ns
 * @param {[Object]} docArray is the post-mutation array of documents to which ns points
 * @param {Object} callbacks
 */
function handleDocArrayMutation (model, method, _arguments, ns, docArray, callbacks) {
  var Model = model.constructor
    , args = _arguments[0]
    , path = args[0]
    , out = _arguments[1]
    , done = callbacks.done;

  var handled = handleNsMutation(model, method, path, args, out, ns, callbacks, function (docs, cb) {
    for (var i = 0, l = docs.length; i < l; i++) cb(docs[i]);
  });

  if (handled) return done && done();

  handled = handleDocMutation(method, path, args, out, ns, callbacks);

  if (handled) return done && done();

  // Handle mutation on a path inside a document that is an immediate child of the namespace
  var suffix = path.substring(ns.length + 1)
    , separatorPos = suffix.indexOf('.')
    , index = parseInt(suffix.substring(0, ~separatorPos ? separatorPos : suffix.length), 10)
    , doc = docArray && docArray[index];
  if (doc) callbacks.onUpdateDocProperty(doc);
  done && done();
}

function handleDocTreeMutation (model, method, _arguments, ns, docTree, callbacks) {
  var Model = model.constructor
    , args = _arguments[0]
    , path = args[0]
    , out = _arguments[1]
    , done = callbacks.done;

  var handled = handleNsMutation(model, method, path, args, out, ns, callbacks, function (docs, cb) {
    for (var k in docs) cb(docs[k]);
  });

  if (handled) return done && done();

  handled = handleDocMutation(method, path, args, out, ns, callbacks);

  if (handled) return done && done();


  // Handle mutation on a path inside a document that is an immediate child of the namespace
  var suffix = path.substring(ns.length + 1)
    , separatorPos = suffix.indexOf('.')
    , id = suffix.substring(0, ~separatorPos ? separatorPos : suffix.length)
    , doc = docTree && docTree[id];
  if (doc) callbacks.onUpdateDocProperty(doc);
  done && done();
}

/**
 * Handle mutation directly on the path to a document that is an immediate
 * child of the namespace.
 */
function handleDocMutation (method, path, args, out, ns, callbacks) {
  // Or directly on the path to a document that is an immediate child of the namespace
  if (path.substring(ns.length + 1).indexOf('.') !== -1) return false;

  // The mutation can:
  switch (method) {
    // (1) remove the document
    case 'del':
      callbacks.onRmDoc(out);
      break;

    // (2) add or over-write the document with a new version of the document
    case 'set':
    case 'setNull':
      callbacks.onAddDoc(args[1], out);
      break;

    default:
      throw new Error('Uncaught edge case');
  }
  return true;
}

/**
 * Handle occurrence when the mutation occured directly on the namespace
 */
function handleNsMutation (model, method, path, args, out, ns, callbacks, iterator) {
  var Model = model.constructor;

  if (path !== ns) return false;
  switch (method) {
    case 'del': callbacks.onRemoveNs(); break;

    case 'set':
    case 'setNull':
      callbacks.onOverwriteNs(args[1], iterator);
      break;

    case 'push':
    case 'insert':
    case 'unshift':
      var docsToAdd = args[Model.arrayMutator[method].insertArgs]
        , onAddDoc = callbacks.onAddDoc;
      if (Array.isArray(docsToAdd)) {
        for (var i = 0, l = docsToAdd.length; i < l; i++) {
          onAddDoc(docsToAdd[i]);
        }
      } else {
        onAddDoc(docsToAdd);
      }
      break;

    case 'pop':
    case 'shift':
    case 'remove':
      var docsToRm = out
        , onRmDoc = callbacks.onRmDoc;
      for (var i = 0, l = docsToRm.length; i < l; i++) {
        onRmDoc(docsToRm[i]);
      }
      break;

    case 'move': // TODO is this the right thing for move?
      var movedIds = out
        , onUpdateDocProperty = callbacks.onUpdateDocProperty
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
        onUpdateDocProperty(doc);
      }
      break;

    default:
      throw new Error('Uncaught edge case');
  }
  return true;
}

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
    var out = model.insert(pointerPath, currResults.length, doc.id);
    return out;
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

function equivId (id, doc) {
  return doc && doc.id === id;
}

/**
 * @param {Array} targets have members who are either Strings representing
 * paths or path patterns OR Arrays representing query tuples of the form
 * [motifName, queryArgs...]
 * @param {Object} opts
 * @api private
 */
function compileTargets (targets, opts) {
  var done = opts.done /* done(targets) or done(targets, scopes) */
    , compileScopedModels = (done.length === 2)
    , parser = new EventEmitter
    , expandedTargets = []
    ;

  var eachPathTarget = opts.eachPathTarget;
  parser.on('path', function (path) {
    eachPathTarget && eachPathTarget(path);
    // TODO push unexpanded target or expanded path?
    expandedTargets.push(path);
  });

  var eachQueryTarget = opts.eachQueryTarget;
  parser.on('query', function (queryTuple) {
    eachQueryTarget && eachQueryTarget(queryTuple);
    expandedTargets.push(queryTuple);
  });

  if (compileScopedModels) {
    var model = opts.model;
    // Compile the list of model scopes representative of the fetched
    // results to pass back to opts.done
    var scopedModels = [];
    parser.on('pattern', function (pattern) {
      // TODO This does not always calc pathUpToGlob
      var pathUpToGlob = splitPath(pattern)[0]
        , scopedModel = model.at(pathUpToGlob);
      scopedModels.push(scopedModel);
    });
    parser.on('query', function (queryTuple) {
      var memoryQuery = model.registeredMemoryQuery(queryTuple)
        , queryId = model.registeredQueryId(queryTuple)
        , scopedModel = setupQueryModelScope(model, memoryQuery, queryId);
      scopedModels.push(scopedModel);
    });
    parser.on('done', function () {
      done.call(model, expandedTargets, scopedModels);
    });
  } else {
    parser.on('done', function () {
      done(expandedTargets);
    });
  }

  parseTargets(parser, targets);
}

/**
 * Parses targets into full set of targets. In particular, patterns need to be
 * expanded into paths. As it's parsing, it emits events:
 *
 * - "pattern" for every target that is a path pattern
 * - "path" for every path that belongs to a set of paths derived from a
 *   pattern target
 * - "query" for every target that is a query tuple
 *
 * @param {EventEmitter} parser
 * @param {Array} targets is an array of strings (representing paths and/or
 * patterns) and/or query tuples (i.e., arrays of the form [motifName,
 * queryArgs...]
 */
function parseTargets (parser, targets) {
  for (var i = 0, l = targets.length; i < l; i++) {
    var target = targets[i];

    if (Array.isArray(target)) { /* If target is a query tuple */
      parser.emit('query', target);
    } else if (target.tuple) {
      parser.emit('query', target.tuple);
    } else { /* Else target is a path or model scope */
      if (target._at) target = target._at;
      parser.emit('pattern', target);
      var paths = expandPath(target);
      for (var k = paths.length; k--; ) {
        parser.emit('path', paths[k]);
      }
    }
  }
  parser.emit('done');
}
