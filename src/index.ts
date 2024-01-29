import { Racer } from './Racer';
import { Model, ModelData } from './Model';
import * as util from './util';
import type { ShareDBOptions } from 'sharedb';

import { RacerBackend } from './Backend';
import { ModelOptions, RootModel } from './Model';
export { Query } from './Model/Query';
export { ChildModel, type UUID, type Subscribable } from './Model';

const { use, serverUse } = util;

type BackendOptions = { modelOptions?: ModelOptions } & ShareDBOptions;

export {
  Model,
  ModelData,
  ModelOptions,
  Racer,
  RacerBackend,
  RootModel,
  use,
  serverUse,
  util,
};

export const racer = new Racer();

export function createModel(data) {
  var model = new RootModel();
  if (data) {
    model.createConnection(data);
    model.unbundle(data);
  }
  return model;
}

export function createBackend(options?: BackendOptions) {
  return new RacerBackend(racer, options);
}
