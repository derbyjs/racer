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

  // for (var i = 0, l = onLoad.length; i < l; i++) {
  //   var item = onLoad[i]
  //     , method = item.shift();
  //   model[method].apply(model, item);
  // }

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
    var serialized = data.subscribedQueries[i];
    var query = model.query(serialized[0], serialized[1], serialized[2]);
    var noFetch = true;
    query.subscribe(noFetch);
  }

  for (var i = 0; i < data.refs.length; i++) {
    var item = data.refs[i];
    model.ref(item[0], item[1]);
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
