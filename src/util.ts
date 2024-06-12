
/** @private */
export const deepEqual = require('fast-deep-equal');

/** 
 * Checks process.title is not equal to 'browser'
 * 
 * Set as 'browser' via build tools (e.g. webpack) to package
 * browser specific code to bundle
 */
export const isServer = process.title !== 'browser';

/** @private */
export function asyncGroup(cb) {
  var group = new AsyncGroup(cb);
  return function asyncGroupAdd() {
    return group.add();
  };
}

type ErrorCallback = (err?: Error) => void;

class AsyncGroup {
  cb: ErrorCallback;
  isDone: boolean;
  count: number;

  constructor(cb: ErrorCallback) {
    this.cb = cb;
    this.isDone = false;
    this.count = 0;
  }

  add() {
    this.count++;
    const self = this;
    return function(err?: Error) {
      self.count--;
      if (self.isDone) return;
      if (err) {
        self.isDone = true;
        self.cb(err);
        return;
      }
      if (self.count > 0) return;
      self.isDone = true;
      self.cb();
    };
  }
}

/** @private */
function castSegment(segment: string | number): string | number {
  return (typeof segment === 'string' && isArrayIndex(segment))
    ? +segment // sneaky op to convert numeric string to number
    : segment;
}

/** @private */
export function castSegments(segments: Readonly<Array<string | number>>) {
  // Cast number path segments from strings to numbers
  return segments.map(segment => castSegment(segment));
}

/** @private */
export function contains(segments, testSegments) {
  for (var i = 0; i < segments.length; i++) {
    if (segments[i] !== testSegments[i]) return false;
  }
  return true;
}

/** @private */
export function copy(value) {
  if (value instanceof Date) return new Date(value);
  if (typeof value === 'object') {
    if (value === null) return null;
    if (Array.isArray(value)) return value.slice();
    return copyObject(value);
  }
  return value;
}

/** @private */
export function copyObject(object) {
  var out = new object.constructor();
  for (var key in object) {
    if (object.hasOwnProperty(key)) {
      out[key] = object[key];
    }
  }
  return out;
}

/** @private */
export function deepCopy(value) {
  if (value instanceof Date) return new Date(value);
  if (typeof value === 'object') {
    if (value === null) return null;
    if (Array.isArray(value)) {
      var array: any[] = [];
      for (var i = value.length; i--;) {
        array[i] = deepCopy(value[i]);
      }
      return array;
    }
    var object = new value.constructor();
    for (var key in value) {
      if (value.hasOwnProperty(key)) {
        object[key] = deepCopy(value[key]);
      }
    }
    return object;
  }
  return value;
}

/** @private */
export function equal(a, b) {
  return (a === b) || (equalsNaN(a) && equalsNaN(b));
}

/** @private */
export function equalsNaN(x) {
  // eslint-disable-next-line no-self-compare
  return x !== x;
}

/** @private */
export function isArrayIndex(segment: string): boolean {
  return (/^[0-9]+$/).test(segment);
}

/** @private */
export function lookup(segments: string[], value: unknown): unknown {
  if (!segments) return value;

  for (var i = 0, len = segments.length; i < len; i++) {
    if (value == null) return value;
    value = value[segments[i]];
  }
  return value;
}

/** @private */
export function mayImpactAny(segmentsList: string[][], testSegments: string[]) {
  for (var i = 0, len = segmentsList.length; i < len; i++) {
    if (mayImpact(segmentsList[i], testSegments)) return true;
  }
  return false;
}

/** @private */
export function mayImpact(segments: string[], testSegments: string[]): boolean {
  var len = Math.min(segments.length, testSegments.length);
  for (var i = 0; i < len; i++) {
    if (segments[i] !== testSegments[i]) return false;
  }
  return true;
}

/** @private */
export function mergeInto(to, from) {
  for (var key in from) {
    to[key] = from[key];
  }
  return to;
}

/** @private */
export function promisify<T = void>(original) {
  if (typeof original !== 'function') {
    throw new TypeError('The "original" argument must be of type Function');
  }

  function fn() {
    var promiseResolve, promiseReject;
    var promise = new Promise<T>(function(resolve, reject) {
      promiseResolve = resolve;
      promiseReject = reject;
    });

    var args = Array.prototype.slice.apply(arguments);
    args.push(function(err: Error, value: T) {
      if (err) {
        promiseReject(err);
      } else {
        promiseResolve(value);
      }
    });

    try {
      original.apply(this, args);
    } catch (err) {
      promiseReject(err);
    }

    return promise;
  }

  return fn;
}

/**
 * Conditionally require module only if in server process. No-op when called in browser.
 * 
 * @param module 
 * @param id 
 * @returns module or undefined
 */
export function serverRequire(module, id) {
  if (!isServer) return;
  return module.require(id);
}

/**
 * Use plugin only if invoked in server process.
 * 
 * @param module 
 * @param id 
 * @param options - Optional  
 * @returns 
 */
export function serverUse(module, id: string, options?: unknown) {
  if (!isServer) return this;
  var plugin = module.require(id);
  return this.use(plugin, options);
}

/**
 * Use plugin
 * 
 * @param plugin
 * @param options - Optional options passed to plugin
 * @returns 
 */
export function use(plugin: (arg0: unknown, options?: unknown) => void, options?: unknown) {
  // Don't include a plugin more than once
  var plugins = this._plugins || (this._plugins = []);
  if (plugins.indexOf(plugin) === -1) {
    plugins.push(plugin);
    plugin(this, options);
  }
  return this;
}
