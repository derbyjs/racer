import { v4 as uuidv4 } from 'uuid';
import { type Context } from './contexts';
import { RacerBackend } from '../Backend';
import { type Connection } from './connection';
import { type ModelData } from './collections';
import { Primitive } from '../types';

export type UUID = string;

export type DefualtType = unknown;

declare module './Model' {
  interface DebugOptions {
    debugMutations?: boolean,
    disableSubmit?: boolean,
    remoteMutations?: boolean,
  }
  
  interface ModelOptions {
    debug?: DebugOptions;
    fetchOnly?: boolean;
    unloadDelay?: number;
    bundleTimeout?: number;
  }

  type ErrorCallback = (err?: Error) => void;
}

type ModelInitFunction = (instance: RootModel, options: ModelOptions) => void;

/**
 * Base class for Racer models
 * 
 * @typeParam T - Type of data the Model contains
 */
export class Model<T = DefualtType> {
  static INITS: ModelInitFunction[] = [];

  ChildModel = ChildModel;
  debug: DebugOptions;
  root: RootModel;
  data: T;

  _at: string;
  _context: Context;
  _eventContext: number | null;
  _events: [];
  _maxListeners: number;
  _pass: any;
  _preventCompose: boolean;
  _silent: boolean;

  /**
   * Creates a new Racer UUID
   * 
   * @returns a new Racer UUID.
   * */
  id(): UUID {
    return uuidv4();
  }

  _child() {
    return new ChildModel(this);
  };
}

/**
 * RootModel is the model that holds all data and maintains connection info
 */
export class RootModel extends Model<ModelData> {
  backend: RacerBackend;
  connection: Connection;

  constructor(options: ModelOptions = {}) {
    super();
    this.root = this;
    var inits = Model.INITS;
    this.debug = options.debug || {};
    for (var i = 0; i < inits.length; i++) {
      inits[i](this, options);
    }
  }
}

/**
 * Model for some subset of the data
 * 
 * @typeParam T - type of data the ChildModel contains.
 */
export class ChildModel<T = DefualtType> extends Model<T> {
  constructor(model: Model<T>) {
    super();
    // Shared properties should be accessed via the root. This makes inheritance
    // cheap and easily extensible
    this.root = model.root;

    // EventEmitter methods access these properties directly, so they must be
    // inherited manually instead of via the root
    this._events = model._events;
    this._maxListeners = model._maxListeners;

    // Properties specific to a child instance
    this._context = model._context;
    this._at = model._at;
    this._pass = model._pass;
    this._silent = model._silent;
    this._eventContext = model._eventContext;
    this._preventCompose = model._preventCompose;
  }
}
