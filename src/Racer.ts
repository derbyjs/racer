import { EventEmitter } from 'events';
import { Model, RootModel } from './Model';
import * as util from './util';

export class Racer extends EventEmitter {
  Model = Model;
  util = util;
  use = util.use;
  serverUse = util.serverUse;

  constructor() {
    super();
  }

  createModel(data) {
    var model = new RootModel();
    if (data) {
      model.createConnection(data);
      model.unbundle(data);
    }
    return model;
  }
}

util.serverRequire(module, './Racer.server');
