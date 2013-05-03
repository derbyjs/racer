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
  model._initQueries(data.subscribedQueries);

  // Re-create refs
  for (var i = 0; i < data.refs.length; i++) {
    var item = data.refs[i];
    model.ref(item[0], item[1]);
  }
  // Re-create refLists
  for (var i = 0; i < data.refLists.length; i++) {
    var item = data.refLists[i];
    model.refList(item[0], item[1], item[2]);
  }
  // TODO: Re-create fns

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
