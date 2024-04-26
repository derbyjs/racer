// @ts-check

import { EventEmitter } from 'events';
import { EventListenerTree } from './EventListenerTree';
import { Model } from './Model';
import { mergeInto } from '../util';
import type { Path, PathLike, Segments } from '../types';

export type ModelEvent =
  | ChangeEvent
  | InsertEvent
  | RemoveEvent
  | MoveEvent
  | LoadEvent
  | UnloadEvent;

export interface ModelOnEventMap {
  change: ChangeEvent;
  insert: InsertEvent;
  remove: RemoveEvent;
  move: MoveEvent;
  load: LoadEvent;
  unload: UnloadEvent;
  all: ModelEvent;
}

/**
 * With `useEventObjects: true` captures are emmitted as
 * ['foo.bar.1']
 *  */
type EventObjectCaptures = string[];

declare module './Model' {
  interface RootModel {
    // duplicated w on signatures below due to how TS handles overrides
    on<T extends keyof ModelOnEventMap>(
      eventType: T,
      pathPattern: PathLike,
      options: { useEventObjects: true },
      listener: (event: ModelOnEventMap[T], captures: EventObjectCaptures) => void
    ): () => void;
    on<T extends keyof ModelOnEventMap>(
      eventType: T,
      options: { useEventObjects: true },
      listener: (event: ModelOnEventMap[T], captures: EventObjectCaptures) => void
    ): () => void;
    on(
      eventType: 'all',
      listener: (pathSegments: string[], event: ModelOnEventMap[keyof ModelOnEventMap]) => void
    ): () => void;
    on(
      eventType: 'error',
      listener: (error: Error) => void
    ): () => void;
  }

  interface Model<T> {
    addListener(event: string, listener: any, arg2?: any, arg3?: any): any;
    eventContext(id: string): ChildModel<T>;
    
    /**
     * Listen to Racer events matching a certain path or path pattern.
     *
     * `pathPattern` is a path pattern that will filter emitted events, calling
     * the handler function only when a mutator matches the pattern.
     *
     * Path patterns support a single segment wildcard `'*'` anywhere in a path,
     * and a multi-segment wildcard `'**'` at the end of the path. The
     * multi-segment wildcard alone `'**'` matches all paths.
     *
     * Examples of path patterns:
     * * `'notes.abc-123.author'` - Trigger on a direct modification to a
     *   specific note's `author`. Will not trigger if a sub-property of the
     *   author is modified or if the entire note is replaced.
     * * `notes.*.author` - Trigger on a direct modification to any note's
     *   `author`. Will not trigger if a sub-property of the author is modified
     *    or if an entire note is replaced.
     * * `notes.*.author.**` - Trigger on a modification to any note's `author`
     *   or any sub-property of `author`. Will not trigger if an entire note is
     *   replaced.
     *
     * @param eventType
     * @param pathPattern
     * @param options
     * @param listener
     *
     * @see https://derbyjs.github.io/derby/models/events
     */
    on<T extends keyof ModelOnEventMap>(
      eventType: T,
      pathPattern: PathLike,
      options: { useEventObjects: true },
      listener: (event: ModelOnEventMap[T], captures: EventObjectCaptures) => void
    ): () => void;
    on<T extends keyof ModelOnEventMap>(
      eventType: T,
      options: { useEventObjects: true },
      listener: (event: ModelOnEventMap[T], captures: EventObjectCaptures) => void
    ): () => void;

    /**
     * Listen to Racer events matching a certain path or path pattern, removing
     * the listener after it gets triggered once.
     *
     * @param eventType
     * @param pathPattern
     * @param options
     * @param listener
     *
     * @see https://derbyjs.github.io/derby/components/events
     */
    once<T extends keyof ModelOnEventMap>(
      eventType: T,
      pathPattern: string,
      options: { useEventObjects: true },
      listener: (event: ModelOnEventMap[T], captures: Array<string | string[]>) => void
    ): Function;
    once<T extends keyof ModelOnEventMap>(
      eventType: T,
      options: { useEventObjects: true },
      listener: (event: ModelOnEventMap[T], captures: Array<string | string[]>) => void
    ): Function;

    /**
     * Passes data to event listeners
     *
     * @param object - An object whose properties will each be set on the passed argument
     * @returns back a model scoped to the same path
     */
    pass(object: object, invert?: boolean): Model<T>;

    removeAllListeners(type: string, subpath: Path): void;
    removeContextListeners(): void;
    
    removeListener(eventType: keyof ModelOnEventMap, listener: Function): void;

    setMaxListeners(limit: number): void;
    silent(value?: boolean): Model<T>;
    wrapCallback(cb?: ErrorCallback): ErrorCallback;

    __on: typeof EventEmitter.prototype.on;
    __once: typeof EventEmitter.prototype.once;
    __removeAllListeners: typeof EventEmitter.prototype.removeAllListeners;
    __removeListener: typeof EventEmitter.prototype.removeListener;
    _addMutationListener(type: string, arg1: any, arg2: any, arg3: any): MutationListener;
    _callMutationListeners(type: string, segments: Segments, event: any): void;
    _defaultCallback(err?: Error): void;
    _emitError(err: Error, context?: any): void;
    _emitMutation(segments: Segments, event: any): void;
    _emittingMutation: boolean;
    _eventContextListeners: Record<string, any>;
    _mutationEventQueue: null;
    _mutationListeners: Record<string, EventListenerTree>;
    _removeAllListeners(type: string, segments: Segments): void;
    _removeMutationListener(listener: MutationListener): void;
  }
}

Model.INITS.push(function(model) {
  var root = model.root;
  EventEmitter.call(root);

  // Set max listeners to unlimited
  model.setMaxListeners(0);

  // Used in async methods to emit an error event if a callback is not supplied.
  // This will throw if there is no handler for model.on('error')
  root._defaultCallback = defaultCallback;
  function defaultCallback(err) {
    if (err) model._emitError(err);
  }

  var mutationListeners = {
    all: new EventListenerTree()
  };

  for (var name in mutationEvents) {
    var eventPrototype = mutationEvents[name].prototype;
    mutationListeners[eventPrototype.type] = new EventListenerTree();
    mutationListeners[eventPrototype._immediateType] = new EventListenerTree();
  }
  root._mutationListeners = mutationListeners;
  root._emittingMutation = false;
  root._mutationEventQueue = null;
  root._pass = new Passed();
  root._silent = false;
  root._eventContextListeners = {};
  root._eventContext = null;
});

mergeInto(Model.prototype, EventEmitter.prototype);

Model.prototype.wrapCallback = function(cb) {
  if (!cb) return this.root._defaultCallback;
  var model = this;
  return function wrappedCallback() {
    try {
      return cb.apply(this, arguments);
    } catch (err) {
      model._emitError(err);
    }
  };
};

Model.prototype._emitError = function(err, context) {
  var message = (err.message) ? err.message :
    (typeof err === 'string') ? err :
      'Unknown model error';
  if (context) {
    message += ' ' + context;
  }
  // @ts-ignore
  if (err.data) {
    try {
      // @ts-ignore
      message += ' ' + JSON.stringify(err.data);
    } catch (stringifyErr) { }
  }
  if (err instanceof Error) {
    err.message = message;
  } else {
    err = new Error(message);
  }
  this.emit('error', err);
};

Model.prototype._emitMutation = function(segments, event) {
  if (this._silent) return;
  var root = this.root;
  this._callMutationListeners(event._immediateType, segments, event);
  if (root._emittingMutation) {
    if (root._mutationEventQueue) {
      root._mutationEventQueue.push(segments, event);
    } else {
      root._mutationEventQueue = [segments, event];
    }
    return;
  }
  root._emittingMutation = true;
  this._callMutationListeners(event.type, segments, event);
  this._callMutationListeners('all', segments, event);
  var limit = 1000;
  while (root._mutationEventQueue) {
    if (--limit < 0) {
      throw new Error(
        'Maximum model mutation event cycles exceeded. Most likely, an event ' +
        'listener is performing a mutation that emits an event to the same ' +
        'listener, directly or indirectly. This creates an infinite cycle. Queue details: \n' +
        JSON.stringify(root._mutationEventQueue, null, 2)
      );
    }
    var queue = root._mutationEventQueue;
    root._mutationEventQueue = null;
    for (var i = 0; i < queue.length;) {
      segments = queue[i++];
      event = queue[i++];
      this._callMutationListeners(event.type, segments, event);
      this._callMutationListeners('all', segments, event);
    }
  }
  root._emittingMutation = false;
};

Model.prototype._callMutationListeners = function(type, segments, event) {
   var tree = this.root._mutationListeners[type];
  var listeners = tree.getWildcardListeners(segments);
  for (var i = 0, len = listeners.length; i < len; i++) {
    var fn = listeners[i].fn;
    fn(segments, event);
  }
};

// EventEmitter.prototype.on, EventEmitter.prototype.addListener, and
// EventEmitter.prototype.once return `this`. The Model equivalents return
// the listener instead, since it is made internally for method subscriptions
// and may need to be passed to removeListener.
Model.prototype.__on = EventEmitter.prototype.on;
// @ts-expect-error ignore method overload issues
Model.prototype.addListener = Model.prototype.on = function(type, arg1, arg2, arg3) {
  var listener = this._addMutationListener(type, arg1, arg2, arg3);
  if (listener) {
    return listener;
  }
  // Normal event
  this.__on(type, arg1);
  return arg1;
};

Model.prototype.__once = EventEmitter.prototype.once;
// @ts-expect-error ignore method overload issues
Model.prototype.once = function(type, arg1, arg2, arg3) {
  var listener = this._addMutationListener(type, arg1, arg2, arg3);
  if (listener) {
    onceWrapListener(this, listener);
    return listener;
  }
  // Normal event
  this.__once(type, arg1);
  return arg1;
};

function onceWrapListener(model, listener) {
  var fn = listener.fn;
  listener.fn = function onceWrapper(segments, event) {
    model._removeMutationListener(listener);
    fn(segments, event);
  };
}

Model.prototype.__removeListener = EventEmitter.prototype.removeListener;
Model.prototype.removeListener = function(type, listener) {
  if (this.root._mutationListeners[type]) {
    this._removeMutationListener(listener);
    return;
  }
  // Normal event
  this.__removeListener(type, listener);
};

Model.prototype.__removeAllListeners = EventEmitter.prototype.removeAllListeners;
Model.prototype.removeAllListeners = function(type, subpath) {
  var segments = this._splitPath(subpath);
  this._removeAllListeners(type, segments);
};
Model.prototype._removeAllListeners = function(type, segments) {
  var mutationListeners = this.root._mutationListeners;
  if (type == null) {
    for (var key in mutationListeners) {
      var tree = mutationListeners[key];
      tree.removeAllListeners(segments);
    }
    return;
  }
  var tree = mutationListeners[type];
  if (tree) {
    tree.removeAllListeners(segments);
    return;
  }
  // Normal event
  this.__removeAllListeners(type);
};

export class Passed { }

Model.prototype.pass = (Object.assign) ?
  function(object, invert) {
    var model = this._child();
    model._pass = (invert) ?
      Object.assign(new Passed(), object, this._pass) :
      Object.assign(new Passed(), this._pass, object);
    return model;
  } :
  function(object, invert) {
    var model = this._child();
    var pass = new Passed();
    if (invert) {
      mergeInto(pass, object);
      mergeInto(pass, this._pass);
    } else {
      mergeInto(pass, this._pass);
      mergeInto(pass, object);
    }
    model._pass = pass;
    return model;
  };

/**
 * The returned Model will or won't trigger event handlers when the model emits
 * events, depending on `value`
 * @param {Boolean|Null} value defaults to true
 * @return {Model}
 */
Model.prototype.silent = function(value) {
  var model = this._child();
  model._silent = (value == null) ? true : !!value;
  return model;
};

Model.prototype.eventContext = function(id) {
  var model = this._child();
  model._eventContext = id;
  return model;
};

Model.prototype.removeContextListeners = function() {
  var id = this._eventContext;
  if (id == null) return;
  var map = this.root._eventContextListeners;
  var listeners = map[id];
  if (!listeners) return;
  delete map[id];
  for (var i = listeners.length; i--;) {
    var listener = listeners[i];
    listener.node.removeOwnListener(listener);
  }
};

Model.prototype._removeMutationListener = function(listener) {
  listener.node.removeOwnListener(listener);
  var id = this._eventContext;
  if (id == null) return;
  var map = this.root._eventContextListeners;
  var listeners = map[id];
  if (!listeners) return;
  // Always iterate though all listeners rather than breaking early. A listener
  // may be in the list more than once, since model._addContextListener()
  // doesn't prevent it at time of adding
  for (var i = listeners.length; i--;) {
    if (listeners[i] === listener) {
      listeners.splice(i, 1);
    }
  }
};

Model.prototype._addMutationListener = function(type, arg1, arg2, arg3) {
  var tree = this.root._mutationListeners[type];
  if (!tree) return;
  // Create double-linked listener and tree node for later removal
  var listener = getMutationListener(this, type, arg1, arg2, arg3);
  var node = tree.addListener(listener.patternSegments, listener);
  listener.node = node;
  // Maintain an index of listeners by eventContext id
  var id = this._eventContext;
  if (id == null) return listener;
  var map = this.root._eventContextListeners;
  var listeners = map[id];
  if (listeners) {
    // Unlike a typical event listener, don't check to see if a listener is
    // already tracked on add. Instead, check to see if the listener might occur
    // more than once when removing. Generally, listeners are expected to be
    // added many at a time during rendering and removed all at once with
    // model.removeContextListeners(). Individual removes are expected to be
    // infrequent and individual adds are expected to be frequent
    listeners.push(listener);
  } else {
    map[id] = [listener];
  }
  return listener;
};

/**
 * @typedef {Object} ModelOnOptions
 * @property {boolean} [useEventObjects] - If true, the listener is called with
 *   `cb(event: ___Event, captures: string[])`, instead of the legacy var-args
 *   style `cb(captures..., [eventType], eventArgs..., passed)`.
 */

/**
 * @param model
 * @param type
 */
function getMutationListener(model, type, arg1, arg2, arg3) {
  var pattern, options, cb;
  if (typeof arg3 === 'function') {
    // on(type, subpath, options, cb)
    pattern = model.path(arg1);
    options = arg2;
    cb = arg3;
  } else if (typeof arg2 === 'function') {
    // on(type, subpath, cb)
    //   model.on('change', 'example.subpath.**', callback)
    //   model.at('example').on('change', 'subpath', callback)
    // on(type, options, cb)
    //   model.at('example').on('change', {useEventObjects: true}, callback)
    pattern = model.path(arg1);
    if (pattern == null) {
      options = arg1;
      pattern = model.path();
    }
    cb = arg2;
  } else if (typeof arg1 === 'function') {
    // on(type, cb)
    //   Normal (non-mutator) event:
    //     model.on('normalEvent', callback)
    //   Path from scoped model:
    //     model.at('example').on('change', callback)
    //   Raw event emission:
    //     model.on('change', callback)
    pattern = model.path();
    cb = arg1;
  } else {
    throw new Error('No expected callback function');
  }
  if (!pattern) {
    // Listen to raw event emission when no path is provided
    return new MutationListener(['**'], model._eventContext, cb);
  }
  pattern = normalizePattern(pattern);
  return (options && options.useEventObjects) ?
    createMutationListener(pattern, model._eventContext, cb) :
    createMutationListenerLegacy(type, pattern, model._eventContext, cb);
}

function createCaptures(captureIndicies, remainingIndex, segments) {
  var captures = [];
  if (captureIndicies) {
    for (var i = 0; i < captureIndicies.length; i++) {
      var index = captureIndicies[i];
      captures.push(segments[index]);
    }
  }
  if (remainingIndex != null) {
    var remainder = segments.slice(remainingIndex).join('.');
    captures.push(remainder);
  }
  return captures;
}

class MutationListener {
  patternSegments: string[];
  eventContext: any;
  fn: any;
  node: any | null;

  constructor(patternSegments, eventContext, fn) {
    this.patternSegments = patternSegments;
    this.eventContext = eventContext;
    this.fn = fn;
    this.node = null;
  }
}

function createMutationListener(pattern, eventContext, cb) {
  var patternSegments = pattern.split('.');
  var fn;
  if (patternSegments.length === 1 && patternSegments[0] === '**') {
    fn = function(segments, event) {
      var captures = [segments.join('.')];
      cb(event, captures);
    };
  } else {
    var captureIndicies, remainingIndex;
    for (var i = 0; i < patternSegments.length; i++) {
      var segment = patternSegments[i];
      if (segment === '*') {
        if (captureIndicies) {
          captureIndicies.push(i);
        } else {
          captureIndicies = [i];
        }
      } else if (segment === '**') {
        if (i !== patternSegments.length - 1) {
          throw new Error('Path pattern may contain `**` at end only');
        }
        remainingIndex = i;
      }
    }
    if (captureIndicies || remainingIndex != null) {
      fn = function(segments, event) {
        var captures = createCaptures(captureIndicies, remainingIndex, segments);
        cb(event, captures);
      };
    } else {
      fn = function(segments, event) {
        cb(event, []);
      };
    }
  }
  return new MutationListener(patternSegments, eventContext, fn);
}

function createMutationListenerLegacy(type, pattern, eventContext, cb) {
  var mutationListenerAdapter = (type === 'all') ?
    function(event, captures) {
      var args = captures.concat(event.type, event._getArgs());
      cb.apply(null, args);
    } :
    function(event, captures) {
      var args = captures.concat(event._getArgs());
      cb.apply(null, args);
    };
  return createMutationListener(pattern, eventContext, mutationListenerAdapter);
}

export class ChangeEvent {
  declare type: 'change';
  declare _immediateType: 'changeImmediate';
  value: any;
  previous: any;
  passed: any;

  constructor(value, previous, passed) {
    this.value = value;
    this.previous = previous;
    this.passed = passed;
  }

  clone() {
    return new ChangeEvent(this.value, this.previous, this.passed);
  };

  _getArgs() {
    return [this.value, this.previous, this.passed];
  };
}
ChangeEvent.prototype.type = 'change';
ChangeEvent.prototype._immediateType = 'changeImmediate';

export class LoadEvent {
  declare type: 'load';
  declare _immediateType: 'loadImmediate';
  value: any;
  document: any;
  passed: any;

  constructor(value, passed) {
    /**
     * The documented public name of the loaded item is `document`
     * However we use `value` internally so both are provided
     * Using `document` is preferred
     */
    this.value = value;
    this.document = value;
    this.passed = passed;
  }

  clone() {
    return new LoadEvent(this.value, this.passed);
  };

  _getArgs() {
    return [this.value, this.passed];
  };
}
LoadEvent.prototype.type = 'load';
LoadEvent.prototype._immediateType = 'loadImmediate';

export class UnloadEvent {
  declare type: 'unload';
  declare _immediateType: 'unloadImmediate';
  previous: any;
  previousDocument: any;
  passed: any;

  constructor(previous, passed) {
    /**
     * The documented public name of the unloaded item is `previousDocument`
     * However we use `previous` internally so both are provided
     * Using `previousDocument` is preferred
     */
    this.previous = previous;
    this.previousDocument = previous;
    this.passed = passed;
  }

  clone() {
    return new UnloadEvent(this.previous, this.passed);
  };

  _getArgs() {
    return [this.previous, this.passed];
  };
}
UnloadEvent.prototype.type = 'unload';
UnloadEvent.prototype._immediateType = 'unloadImmediate';

export class InsertEvent {
  declare type: 'insert';
  declare _immediateType: 'insertImmediate';
  index: number;
  values: any[];
  passed: any;

  constructor(index, values, passed) {
    this.index = index;
    this.values = values;
    this.passed = passed;
  }

  clone() {
    return new InsertEvent(this.index, this.values, this.passed);
  };

  _getArgs() {
    return [this.index, this.values, this.passed];
  };
}
InsertEvent.prototype.type = 'insert';
InsertEvent.prototype._immediateType = 'insertImmediate';

export class RemoveEvent {
  declare type: 'remove';
  declare _immediateType: 'removeImmediate';
  index: number;
  passed: any;
  removed: any[];
  /** @deprecated Use `removed` instead */
  values: any[];

  constructor(index, values, passed) {
    this.index = index;
    /**
     * The documented public name of the removed item is `removed`
     * However we use `values` internally so both are provided
     * Using `removed` is preferred
     */
    this.values = values;
    this.removed = values;
    this.passed = passed;
  }

  clone() {
    return new RemoveEvent(this.index, this.values, this.passed);
  };

  _getArgs() {
    return [this.index, this.values, this.passed];
  };
}
RemoveEvent.prototype.type = 'remove';
RemoveEvent.prototype._immediateType = 'removeImmediate';

export class MoveEvent {
  declare type: 'move';
  declare _immediateType: 'moveImmediate';
  from: number;
  howMany: number;
  passed: any;
  to: number;

  constructor(from, to, howMany, passed) {
    this.from = from;
    this.to = to;
    this.howMany = howMany;
    this.passed = passed;
  }

  clone() {
    return new MoveEvent(this.from, this.to, this.howMany, this.passed);
  };

  _getArgs() {
    return [this.from, this.to, this.howMany, this.passed];
  };
}
MoveEvent.prototype.type = 'move';
MoveEvent.prototype._immediateType = 'moveImmediate';

// DEPRECATED: Normalize pattern ending in '**' to '.**', since these are
// treated equivalently. The '.**' form is preferred, and it should be enforced
// in a future version for clarity
function normalizePattern(pattern) {
  var end = pattern.length - 1;
  return (
    pattern.charAt(end) === '*' &&
    pattern.charAt(end - 1) === '*' &&
    pattern.charAt(end - 2) !== '.' &&
    pattern.charAt(end - 2)
  ) ? pattern.slice(0, end - 1) + '.**' : pattern;
};


// These events are re-emitted as 'all' events, and they are queued up and
// emitted in sequence, so that events generated by other events are not
// seen in a different order by later listeners
export const mutationEvents = {
  ChangeEvent,
  LoadEvent,
  UnloadEvent,
  InsertEvent,
  RemoveEvent,
  MoveEvent,
};