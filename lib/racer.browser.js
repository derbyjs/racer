// WARNING
// All racer modules for the browser should be included in racer.coffee and not
// in this file.

var configuration = require('./configuration');

module.exports = plugin;

function plugin(racer) {
  var envs = ['browser'];
  configuration.makeConfigurable(racer, envs);

  racer.init = init;
  racer.ready = ready;
  racer._model = new racer.Model;
  racer._isReady = false;
}

function init(data) {
  var model = this._model;

  // TODO: Configuration methods don't account for this env value not being
  // available right away
  // model.flags = flags;
  // envs.push(model.flags.nodeEnv);

  model._createConnection();

  // Re-create documents for all model data
  for (var collectionName in data.collections) {
    var collection = data.collections[collectionName];
    for (var id in collection) {
      model.getOrCreateDoc(collectionName, id, collection[id]);
    }
  }
  // Re-subscribe to document subscriptions
  for (var path in data.subscribedDocs) {
    var count = data.subscribedDocs[path];
    var segments = path.split('.');
    model.subscribeDoc(segments[0], segments[1]);
  }
  // Re-subscribe to query subscriptions
  for (var i = 0; i < data.subscribedQueries.length; i++) {
    var item = data.subscribedQueries[i];
    var query = model.query(item[0], item[1], item[2]);
    // Slice the ids to make sure that they are the value at inital load time
    var ids = model._get(['_$queries', query.hash, 'ids']);
    ids = (ids) ? ids.slice() : [];
    reinitQuery(query, item[3], ids);
  }
  function reinitQuery(query, subscriptionCount, ids) {
    query.reinit(subscriptionCount, function() {
      // On reinit, the query subscription will again subscribe to documents
      // that were already subscribed above. However, the query results could
      // now be different than they were on the server, so we allow for them
      // to be subscribed twice, and then we unsubscribe from items that were
      // part of the results set at initial load time
      for (var i = 0; i < ids.length; i++) {
        model.unsubscribeDoc(query.collectionName, ids[i]);
      }
    });
  }

  for (var i = 0; i < data.refs.length; i++) {
    var item = data.refs[i];
    model.ref(item[0], item[1]);
  }
  for (var i = 0; i < data.refLists.length; i++) {
    var item = data.refLists[i];
    model.refList(item[0], item[1], item[2]);
  }

  this.emit('init', model);

  this._isReady = true;
  this.emit('ready', model);
  return this;
}

function ready(onready) {
  var racer = this;
  return function () {
    if (racer._isReady) return onready(racer._model);
    racer.on('ready', onready);
  };
}
