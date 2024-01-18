import { Racer } from './Racer';
import { Model, ModelData } from './Model';
import * as util from './util';

import { RacerBackend } from './Backend';
export { Query } from './Model/Query';
export { ChildModel, RootModel } from './Model';

const { use, serverUse } = util;

export {
  Model,
  ModelData,
  Racer,
  RacerBackend,
  use,
  serverUse,
  util,
};

export const racer = new Racer();

export function createModel(data) {
  var model = new Model();
  if (data) {
    model.createConnection(data);
    model.unbundle(data);
  }
  return model;
}

export function createBackend(options) {
  return new RacerBackend(racer, options);
};
