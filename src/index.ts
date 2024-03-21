import { Racer } from './Racer';
import * as util from './util';
import type { ShareDBOptions } from 'sharedb';

import { RacerBackend } from './Backend';
import { RootModel, type ModelOptions } from './Model';

export { Query } from './Model/Query';
export { Model, ChildModel, ModelData, type UUID, type Subscribable, type DefualtType, type ModelOptions } from './Model';
export { Context } from './Model/contexts';
export { type ModelOnEventMap, type ModelEvent, ChangeEvent, InsertEvent, LoadEvent, MoveEvent, RemoveEvent, UnloadEvent } from './Model/events';
export type { Callback, ReadonlyDeep, Path, PathLike, PathSegment, Primitive } from './types';
export type { CollectionData } from './Model/collections';
export * as util from './util';

const { use, serverUse } = util;

export type BackendOptions = { modelOptions?: ModelOptions } & ShareDBOptions;

export {
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
