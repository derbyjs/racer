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

  for (var collectionName in data.snapshot) {
    var collection = data.snapshot[collectionName];
    for (var id in collection) {
      model.getOrCreateDoc(collectionName, id, collection[id]);
    }
  }
  for (var i = 0; i < data.subscribedDocs.length; i++) {
    var path = data.subscribedDocs[i];
    var segments = path.split('.');
    model.subscribeDoc(segments[0], segments[1]);
  }
  for (var i = 0; i < data.subscribedQueries.length; i++) {
    var item = data.subscribedQueries[i];
    var query = model.query(item[0], item[1], item[2]);
    var noFetch = true;
    query.subscribe(noFetch);
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
