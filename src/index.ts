import { Racer } from './Racer';
import * as util from './util';
import type { ShareDBOptions } from 'sharedb';

import { RacerBackend } from './Backend';
import { ModelOptions, RootModel } from './Model';

export { Query } from './Model/Query';
export { Model, ChildModel, ModelData, type UUID, type Subscribable } from './Model';
export { Context } from './Model/contexts';
export type { ReadonlyDeep, Path, PathLike, PathSegment } from './types';
export * as util from './util';

const { use, serverUse } = util;

export type BackendOptions = { modelOptions?: ModelOptions } & ShareDBOptions;

export {
  ModelOptions,
  Racer,
  RacerBackend,
  RootModel,
  use,
  serverUse,
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
