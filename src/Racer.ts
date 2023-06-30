var EventEmitter = require('events').EventEmitter;
var Model = require('./Model');
var util = require('./util');


export class Racer extends EventEmitter {
  Model: typeof Model = Model;
  util = util;
  use = util.use;
  serverUse = util.serverUse;

  constructor() {
    super();
  }

  createModel(data) {
    var model = new Model();
    if (data) {
      model.createConnection(data);
      model.unbundle(data);
    }
    return model;
  }
}

util.serverRequire(module, './Racer.server');
