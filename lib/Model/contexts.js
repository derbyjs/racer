/**
 * Contexts are useful for keeping track of the origin of subscribes.
 */

var Model = require('./index');
var Query = require('./Query');

Model.INITS.push(function(model) {
  model._contexts = new Contexts;
  model.setContext('root');
  [ 'fetchDoc', 'subscribeDoc', 'unfetchDoc', 'unsubscribeDoc'
  , 'fetchQuery', 'subscribeQuery', 'unfetchQuery', 'unsubscribeQuery'
  ].forEach(function(event) {
    model.on(event, function(item, context, pass) {
      context[event](item, pass);
    });
  });
});

Model.prototype.context = function(id) {
  var model = Object.create(this);
  model.setContext(id);
  return model;
};

Model.prototype.setContext = function(id) {
  var context = this._contexts[id] || new Context(this, id);
  this._context = this._contexts[id] = context;
  return context;
};

Model.prototype.unload = function(id) {
  var context = (id) ? this._contexts[id] : this._context;
  context.unload();
};

function Contexts() {}

function FetchedDocs() {}
function SubscribedDocs() {}
function FetchedQueries() {}
function SubscribedQueries() {}

function Context(model, id) {
  this.model = model;
  this.id = id;
  this.fetchedDocs = new FetchedDocs;
  this.subscribedDocs = new SubscribedDocs;
  this.fetchedQueries = new FetchedQueries;
  this.subscribedQueries = new SubscribedQueries;
}

Context.prototype.toJSON = function() {
  return {
    fetchedDocs: this.fetchedDocs
  , subscribedDocs: this.subscribedDocs
  , fetchedQueries: this.fetchedQueries
  , subscribedQueries: this.subscribedQueries
  };
};

Context.prototype.fetchDoc = function(path, pass) {
  if (pass.$query) return;
  mapIncrement(this.fetchedDocs, path);
};
Context.prototype.subscribeDoc = function(path, pass) {
  if (pass.$query) return;
  mapIncrement(this.subscribedDocs, path);
};
Context.prototype.unfetchDoc = function(path, pass) {
  if (pass.$query) return;
  mapDecrement(this.fetchedDocs, path);
};
Context.prototype.unsubscribeDoc = function(path, pass) {
  if (pass.$query) return;
  mapDecrement(this.subscribedDocs, path);
};
Context.prototype.fetchQuery = function(query) {
  mapIncrement(this.fetchedQueries, query.hash);
};
Context.prototype.subscribeQuery = function(query) {
  mapIncrement(this.subscribedQueries, query.hash);
};
Context.prototype.unfetchQuery = function(query) {
  mapDecrement(this.fetchedQueries, query.hash);
};
Context.prototype.unsubscribeQuery = function(query) {
  mapDecrement(this.subscribedQueries, query.hash);
};
function mapIncrement(map, key) {
  map[key] = (map[key] || 0) + 1;
}
function mapDecrement(map, key) {
  map[key] && map[key]--;
  if (!map[key]) delete map[key];
}

Context.prototype.unload = function() {
  var model = this.model;
  for (var hash in this.fetchedQueries) {
    var query = model._queries.map[hash];
    if (!query) continue;
    var count = this.fetchedQueries[hash];
    while (count--) query.unfetch(null);
  }
  for (var hash in this.subscribedQueries) {
    var query = model._queries.map[hash];
    if (!query) continue;
    var count = this.subscribedQueries[hash];
    while (count--) query.unsubscribe(null);
  }
  for (var path in this.fetchedDocs) {
    var segments = path.split('.');
    var count = this.fetchedDocs[path];
    while (count--) model.unfetchDoc(segments[0], segments[1]);
  }
  for (var path in this.subscribedDocs) {
    var segments = path.split('.');
    var count = this.subscribedDocs[path];
    while (count--) model.unsubscribeDoc(segments[0], segments[1]);
  }
  this.model._context = this.model._contexts[this.id] =
    new Context(this.model, this.id);
};
