var util = require('../util');
var Model = require('./index');
var Query = require('./Query');

Model.INITS.push(function(model, options) {
  model.fetchOnly = options.fetchOnly;
  model.unloadDelay = options.unloadDelay || 1000;

  // Keeps track of the count of fetches (that haven't been undone by an
  // unfetch) per doc. Maps doc id to the fetch count.
  model._fetchedDocs = new FetchedDocs;

  // Keeps track of the count of subscribes (that haven't been undone by an
  // unsubscribe) per doc. Maps doc id to the subscribe count.
  model._subscribedDocs = new SubscribedDocs;

  // Maps doc id to doc version
  model._loadVersions = new LoadVersions;
});

function FetchedDocs() {}
function SubscribedDocs() {}
function LoadVersions() {}

Model.prototype.fetch = function() {
  this._forSubscribable(arguments, 'fetch');
  return this;
};
Model.prototype.unfetch = function() {
  this._forSubscribable(arguments, 'unfetch');
  return this;
};
Model.prototype.subscribe = function() {
  this._forSubscribable(arguments, 'subscribe');
  return this;
};
Model.prototype.unsubscribe = function() {
  this._forSubscribable(arguments, 'unsubscribe');
  return this;
};

/**
 * @private
 * @param {Arguments} argumentsObject can take 1 of two forms
 *   1. [[subscribableObjects...], cb]
 *   2. [subscribableObjects..., cb]
 * @param {String} method can be 'fetch', 'unfetch', 'subscribe', 'unsubscribe'
 */
Model.prototype._forSubscribable = function(argumentsObject, method) {
  if (Array.isArray(argumentsObject[0])) {
    var args = argumentsObject[0];
    var cb = argumentsObject[1] || this._defaultCallback;
  } else {
    var args = Array.prototype.slice.call(argumentsObject);
    var last = args[args.length - 1];
    var cb = (typeof last === 'function') ? args.pop() : this._defaultCallback;
  }
  // If no queries or paths are passed in, try to use this model's scope
  if (!args.length) args.push(null);
  var group = util.asyncGroup(cb);
  var docMethod = method + 'Doc';

  for (var i = 0; i < args.length; i++) {
    var item = args[i];
    if (item instanceof Query) {
      item[method](group());
    } else {
      var segments = this._dereference(this._splitPath(item));
      if (segments.length === 2) {
        // Do the appropriate method for a single document.
        this[docMethod](segments[0], segments[1], group());
      } else if (segments.length === 1) {
        // Make a query to an entire collection.
        var query = this.query(segments[0], {});
        query[method](group());
      } else if (segments.length === 0) {
        var message = 'No path specified for ' + method;
        this.emit('error', new Error(message));
      } else {
        var message = 'Cannot ' + method + ' to a path within a document: ' +
          segments.join('.');
        this.emit('error', new Error(message));
      }
    }
  }
};

/**
 * @param {String}
 * @param {String} id
 * @param {Function} cb(err)
 * @param {Boolean} alreadyLoaded
 */
Model.prototype.fetchDoc = function(collectionName, id, cb, alreadyLoaded) {
  if (!cb) cb = this._defaultCallback;

  // Maintain a count of fetches so that we can unload the document when
  // there are no remaining fetches or subscribes for that document
  var path = collectionName + '.' + id;
  this.emit('fetchDoc', path, this._context, this._pass);
  this._fetchedDocs[path] = (this._fetchedDocs[path] || 0) + 1;

  var model = this;
  var doc = this.getOrCreateDoc(collectionName, id);
  if (alreadyLoaded) {
    process.nextTick(fetchDocCallback);
  } else {
    doc.shareDoc.fetch(fetchDocCallback);
  }
  function fetchDocCallback(err) {
    if (err) return cb(err);
    if (doc.shareDoc.version && doc.shareDoc.version !== model._loadVersions[path]) {
      model._loadVersions[path] = doc.shareDoc.version;
      model.emit('load', [collectionName, id], [doc.get(), model._pass]);
    }
    cb();
  }
};

/**
 * @param {String} collectionName
 * @param {String} id of the document we want to subscribe to
 * @param {Function} cb(err)
 */
Model.prototype.subscribeDoc = function(collectionName, id, cb) {
  if (!cb) cb = this._defaultCallback;

  var path = collectionName + '.' + id;
  this.emit('subscribeDoc', path, this._context, this._pass);
  var count = this._subscribedDocs[path] = (this._subscribedDocs[path] || 0) + 1;
  // Already requested a subscribe, so just return
  if (count > 1) return cb();

  // Subscribe if currently unsubscribed
  var model = this;
  var doc = this.getOrCreateDoc(collectionName, id);
  if (this.fetchOnly) {
    // Only fetch if the document isn't already loaded
    if (doc.get() === void 0) {
      doc.shareDoc.fetch(subscribeDocCallback);
    } else {
      process.nextTick(subscribeDocCallback);
    }
  } else {
    doc.shareDoc.subscribe(subscribeDocCallback);
  }
  function subscribeDocCallback(err) {
    if (err) return cb(err);
    if (doc.shareDoc.version && doc.shareDoc.version !== model._loadVersions[path]) {
      model._loadVersions[path] = doc.shareDoc.version;
      model.emit('load', [collectionName, id], [doc.get(), model._pass]);
    }
    cb();
  }
};

Model.prototype.unfetchDoc = function(collectionName, id, cb) {
  if (!cb) cb = this._defaultCallback;
  var path = collectionName + '.' + id;
  this.emit('unfetchDoc', path, this._context, this._pass);
  var fetchedDocs = this._fetchedDocs;

  // No effect if the document has no fetch count
  if (!fetchedDocs[path]) return cb();

  var model = this;
  if (this.unloadDelay && !this._pass.$query) {
    setTimeout(finishUnfetchDoc, this.unloadDelay);
  } else {
    finishUnfetchDoc();
  }
  function finishUnfetchDoc() {
    var count = --fetchedDocs[path];
    if (count) return cb(null, count);
    delete fetchedDocs[path];
    model._maybeUnloadDoc(collectionName, id, path);
    cb(null, 0);
  }
};

Model.prototype.unsubscribeDoc = function(collectionName, id, cb) {
  if (!cb) cb = this._defaultCallback;
  var path = collectionName + '.' + id;
  this.emit('unsubscribeDoc', path, this._context, this._pass);
  var subscribedDocs = this._subscribedDocs;

  // No effect if the document is not currently subscribed
  if (!subscribedDocs[path]) return cb();

  var model = this;
  if (this.unloadDelay && !this._pass.$query) {
    setTimeout(finishUnsubscribeDoc, this.unloadDelay);
  } else {
    finishUnsubscribeDoc();
  }
  function finishUnsubscribeDoc() {
    var count = --subscribedDocs[path];
    // If there are more remaining subscriptions, only decrement the count
    // and callback with how many subscriptions are remaining
    if (count) return cb(null, count);

    // If there is only one remaining subscription, actually unsubscribe
    delete subscribedDocs[path];
    if (model.fetchOnly) {
      unsubscribeDocCallback();
    } else {
      var shareDoc = model.shareConnection.get(collectionName, id);
      if (!shareDoc) {
        return cb(new Error('Share document not found for: ' + path));
      }
      shareDoc.unsubscribe(unsubscribeDocCallback);
    }
  }
  function unsubscribeDocCallback(err) {
    model._maybeUnloadDoc(collectionName, id, path);
    if (err) return cb(err);
    cb(null, 0);
  }
};

/**
 * Removes the document from the local model if the model no longer has any
 * remaining fetches or subscribes on path.
 * Called from Model.prototype.unfetchDoc and Model.prototype.unsubscribeDoc as
 * part of attempted cleanup.
 * @param {String} collectionName
 * @param {String} id
 * @param {String} path
 */
Model.prototype._maybeUnloadDoc = function(collectionName, id, path) {
  var doc = this.getDoc(collectionName, id);
  if (!doc) return;
  // Remove the document from the local model if it no longer has any
  // remaining fetches or subscribes
  if (this._fetchedDocs[path] || this._subscribedDocs[path]) return;
  var previous = doc.get();
  this.collections[collectionName].remove(id);
  if (doc.shareDoc) doc.shareDoc.destroy();
  delete this._loadVersions[path];
  this.emit('unload', [collectionName, id], [previous, this._pass]);
};

Model.prototype._getOrCreateShareDoc = function(collectionName, id, data) {
  var shareDoc = this.shareConnection.getOrCreate(collectionName, id, data);
  shareDoc.incremental = true;
  return shareDoc;
};
