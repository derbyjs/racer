import { v4 as uuidv4 } from 'uuid';
import { EventEmitter } from 'events';
import { Context } from 'vm';

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


type ModelInitFunction = (instance: Model, options: ModelOptions) => void;

export class Model {
  static INITS: ModelInitFunction[] = [];

  ChildModel = ChildModel;
  debug: DebugOptions;
  root: Model;

  _at: () => Model;
  _context: Context;
  _eventContext: number | null;
  _events: [];
  _maxListeners: number;
  _pass: any;
  _preventCompose: boolean;
  _silent: boolean;

  constructor(options: ModelOptions = {}) {
    this.root = this;
    var inits = Model.INITS;
    this.debug = options.debug || {};
    for (var i = 0; i < inits.length; i++) {
      inits[i](this, options);
    }
  }

  id() {
    return uuidv4();
  }

  _child() {
    return new ChildModel(this);
  };
}

export class ChildModel extends Model {
  constructor(model: Model) {
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
