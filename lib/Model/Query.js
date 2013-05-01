var racer = require('../racer');
var Model = require('./index');
module.exports = Query;

racer.on('Model:init', function(model) {
  model._queries = new Queries;
});

function Queries() {}

function Query(model, collectionName, sourceQuery, source) {
  this.model = model;
  this.collectionName = collectionName;
  this.sourceQuery = sourceQuery;
  this.source = source;

  this.shareQuery = model.shareConnection.createQuery(collectionName, sourceQuery, source);
}

Query.prototype.subscribe = function(noFetch, cb) {
  if (typeof noFetch === 'function') {
    cb = noFetch;
    noFetch = false;
  }

  var model = this.model;
  if (!cb) cb = model._defaultCallback;
  var query = this;
  if (this.isSubscribed) {
    this.shareQuery.whenReady(function() {
      cb();
    });
    return;
  }
  this.isSubscribed = true;

  this.shareQuery.autoFetch = !noFetch;
  this.shareQuery.subscribe();
  //this.shareQuery.on('error', cb);
  this.shareQuery.whenReady(function() {
    var results = query.shareQuery.results;
    for (var i = 0; i < results.length; i++) {
      var doc = results[i];
      model.subscribeDoc(doc.collection, doc.name);
    }
    cb();
  });
};

Query.prototype.serialize = function() {
  return serializeQuery(this.collectionName, this.sourceQuery, this.source);
};

function serializeQuery(collectionName, sourceQuery, source) {
  return [collectionName, sourceQuery, source];
}

Model.prototype.query = function(collectionName, sourceQuery, source) {
  var hash = JSON.stringify(serializeQuery(collectionName, sourceQuery, source));
  var query = this._queries[hash];
  if (query) return query;
  query = new Query(this, collectionName, sourceQuery, source);
  this._queries[hash] = query;
  return query;
};

