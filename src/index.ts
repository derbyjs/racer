import { Racer } from './Racer';
import * as util from './util';
import type { ShareDBOptions } from 'sharedb';

export { type RacerBackend, type BackendOptions } from './Backend';
import { RootModel } from './Model';
import { type BackendOptions } from './Backend';

export { Query } from './Model/Query';
export { Model, ChildModel, ModelData, type UUID, type Subscribable, type DefualtType, type ModelOptions } from './Model';
export { Context } from './Model/contexts';
export { type ModelOnEventMap, type ModelEvent, ChangeEvent, InsertEvent, LoadEvent, MoveEvent, RemoveEvent, UnloadEvent } from './Model/events';
export type { Callback, ReadonlyDeep, Path, PathLike, PathSegment, Primitive } from './types';
export type { CollectionData } from './Model/collections';
export * as util from './util';

const { use, serverUse } = util;

export {
  Racer,
  RootModel,
  use,
  serverUse,
};

export const racer = new Racer();

/**
 * Creates new RootModel
 * 
 * @param data - Optional Data to initialize model with
 * @returns RootModel
 */
export function createModel(data?) {
  var model = new RootModel();
  if (data) {
    model.createConnection(data);
    model.unbundle(data);
  }
  return model;
}

/**
 * Creates racer backend. Can only be called in server process and throws error if called in browser.
 * 
 * @param options - Optional
 * @returns racer backend
 */
export function createBackend(options?: BackendOptions) {
  const backendModule = util.serverRequire(module, './Backend');
  if (backendModule == null) {
    throw new Error('racer.createBackend can only be called in server node process');
  }
  return new backendModule.RacerBackend(racer, options);
}
