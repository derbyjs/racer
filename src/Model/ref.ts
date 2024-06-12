import { EventListenerTree } from './EventListenerTree';
import { EventMapTree } from './EventMapTree';
import { Model } from './Model';
import { type Filter } from './filter';
import { type Query } from './Query';
import type { Path, PathLike, Segments } from '../types';

type Refable = string | number | Model<any> | Query | Filter<unknown>;

export interface RefOptions {
  /**
   * If true, indicies will be updated.
   */
  updateIndices: boolean;
}

export interface RefListOptions {
  /**
   * If true, then objects from the source collection will be deleted if the
   * corresponding item is removed from the refList's output path.
   */
  deleteRemoved: boolean,
}

declare module './Model' {
  interface Model {
    /**
     * Creates an array at `outputPath` that consists of references to all the
     * objects at `collectionPath` that have ids matching the ids at `idsPath`.
     * The array is automatically updated based on changes to the input paths.
     *
     * @param outputPath - Path at which to create the ref list. This must be
     *   under a local collection, typically `'_page'` or a component model.
     * @param collectionPath - Path to a Racer collection or a collection-like
     *   object, where each id string key maps to an object value with matching
     *   `id` property.
     * @param idsPath - Path to an array of string ids
     * @param options - Optional
     *
     * @see https://derbyjs.github.io/derby/models/refs
     */
    refList<S>(outputPath: PathLike, collectionPath: PathLike, idsPath: PathLike, options?: RefListOptions): ChildModel<S>;

    _canRefTo(value: Refable): boolean;
    // _canRefTo(from: Segments, to: Segments, options: RefOptions): boolean;

    /**
     * Creates a reference for this model pointing to another path `to`. Like a
     * symlink, any reads/writes on this `to` ref will work as if they were done on
     * `path` directly.
     *
     * @param to - Location that the reference points to
     * @return a model scoped to `path`
     *
     * @see https://derbyjs.github.io/derby/models/refs
     */
    ref<S>(to: PathLike): ChildModel<S>;
    /**
     * Creates a reference at `path` pointing to another path `to`. Like a
     * symlink, any reads/writes on `path` will work as if they were done on
     * `path` directly.
     *
     * @param path - Location at which to create the reference. This must be
     *   under a local collection, typically `'_page'` or a component model.
     * @param to - Location that the reference points to
     * @params options - Optional {@link RefOptions}
     * @return a model scoped to `path`
     *
     * @see https://derbyjs.github.io/derby/models/refs
     */
    ref<S>(path: PathLike, to: PathLike, options?: RefOptions): ChildModel<S>;
    _ref<T>(from: Segments, to: Segments, options?: RefOptions): void;

    /**
     * Removes a model reference.
     *
     * @param path - Location of the reference to remove
     *
     * @see https://derbyjs.github.io/derby/models/refs
     */
    removeRef(path: PathLike): void;
    _removeRef(segments: Segments): void;

    removeAllRefs(subpath: PathLike): void;
    _removeAllRefs(segments: Segments): void;

    dereference(subpath: Path): Segments;
    _dereference(segments: Segments, forArrayMutator: any, ignore: boolean): Segments;

    _refs: any;
    _refLists: any;
  }
}


Model.INITS.push(function(model) {
  var root = model.root;
  root._refs = new Refs();
  addIndexListeners(root);
  addListener(root, 'changeImmediate', refChange);
  addListener(root, 'loadImmediate', refLoad);
  addListener(root, 'unloadImmediate', refUnload);
  addListener(root, 'insertImmediate', refInsert);
  addListener(root, 'removeImmediate', refRemove);
  addListener(root, 'moveImmediate', refMove);
});

function addIndexListeners(model) {
  model.on('insertImmediate', function refInsertIndex(segments, event) {
    var index = event.index;
    var howMany = event.values.length;
    function patchInsert(refIndex) {
      return (index <= refIndex) ? refIndex + howMany : refIndex;
    }
    onIndexChange(segments, patchInsert);
  });
  model.on('removeImmediate', function refRemoveIndex(segments, event) {
    var index = event.index;
    var howMany = event.values.length;
    function patchRemove(refIndex) {
      return (index <= refIndex) ? refIndex - howMany : refIndex;
    }
    onIndexChange(segments, patchRemove);
  });
  model.on('moveImmediate', function refMoveIndex(segments, event) {
    var from = event.from;
    var to = event.to;
    var howMany = event.howMany;
    function patchMove(refIndex) {
      // If the index was moved itself
      if (from <= refIndex && refIndex < from + howMany) {
        return refIndex + to - from;
      }
      // Remove part of a move
      if (from <= refIndex) refIndex -= howMany;
      // Insert part of a move
      if (to <= refIndex) refIndex += howMany;
      return refIndex;
    }
    onIndexChange(segments, patchMove);
  });
  function onIndexChange(segments, patch) {
    var toListeners = model._refs.toListeners;
    var refs = toListeners.getDescendantListeners(segments);
    for (var i = 0; i < refs.length; i++) {
      var ref = refs[i];
      if (!ref.updateIndices) continue;
      var index = +ref.toSegments[segments.length];
      var patched = patch(index);
      if (index === patched) continue;
      toListeners.removeListener(ref.toSegments, ref);
      ref.toSegments[segments.length] = '' + patched;
      ref.to = ref.toSegments.join('.');
      toListeners.addListener(ref.toSegments, ref);
    }
  }
}

function refChange(model, dereferenced, event, segments) {
  var value = event.value;
  // Detect if we are deleting vs. setting to undefined
  if (value === undefined) {
    var parentSegments = segments.slice();
    var last = parentSegments.pop();
    var parent = model._get(parentSegments);
    if (!parent || !(last in parent)) {
      model._del(dereferenced);
      return;
    }
  }
  model._set(dereferenced, value);
}
function refLoad(model, dereferenced, event) {
  model._set(dereferenced, event.value);
}
function refUnload(model, dereferenced) {
  model._del(dereferenced);
}
function refInsert(model, dereferenced, event) {
  model._insert(dereferenced, event.index, event.values);
}
function refRemove(model, dereferenced, event) {
  model._remove(dereferenced, event.index, event.values.length);
}
function refMove(model, dereferenced, event) {
  model._move(dereferenced, event.from, event.to, event.howMany);
}

function addListener(model, type, fn) {
  model.on(type, refListener);
  function refListener(segments, event) {
    var passed = event.passed;
    // Find cases where an event is emitted on a path where a reference
    // is pointing. All original mutations happen on the fully dereferenced
    // location, so this detection only needs to happen in one direction
    var node = model._refs.toListeners;
    for (var i = 0; i < segments.length; i++) {
      var segment = segments[i];
      node = node.children && node.children.values[segment];
      if (!node) return;
      // If a ref is found pointing to a matching subpath, re-emit on the
      // place where the reference is coming from as if the mutation also
      // occured at that path
      var refs = node.listeners;
      if (!refs) continue;

      // Shallow clone refs in case a ref is removed while going through
      // the loop
      refs = refs.slice();
      var remaining = segments.slice(i + 1);
      for (var refIndex = 0; refIndex < refs.length; refIndex++) {
        var ref = refs[refIndex];
        var dereferenced = ref.fromSegments.concat(remaining);
        // The value may already be up to date via object reference. If so,
        // simply re-emit the event. Otherwise, perform the same mutation on
        // the ref's path
        if (model._get(dereferenced) === model._get(segments)) {
          model._emitMutation(dereferenced, event);
        } else {
          var setterModel = model.pass(passed);
          setterModel._dereference = noopDereference;
          fn(setterModel, dereferenced, event, segments);
        }
      }
    }
    // If a ref points to a child of a matching subpath, get the value in
    // case it has changed and set if different
    var refs = node.getOwnDescendantListeners();
    for (var i = 0; i < refs.length; i++) {
      var ref = refs[i];
      var value = model._get(ref.toSegments);
      var previous = model._get(ref.fromSegments);
      if (previous !== value) {
        var setterModel = model.pass(passed);
        setterModel._dereference = noopDereference;
        setterModel._set(ref.fromSegments, value);
      }
    }
  }
}

Model.prototype._canRefTo = function(value) {
  return this.isPath(value) || (value && typeof (value as any).ref === 'function');
};

Model.prototype.ref = function() {
  var from, to, options;
  // to could be pathlike, model, query, or filter 
  if (arguments.length === 1) {
    to = arguments[0];
  } else if (arguments.length === 2) {
    if (this._canRefTo(arguments[1])) {
      from = arguments[0];
      to = arguments[1];
    } else {
      to = arguments[0];
      options = arguments[1];
    }
  } else {
    from = arguments[0];
    to = arguments[1];
    options = arguments[2];
  }
  var fromPath = this.path(from);
  var toPath = this.path(to);
  // Make ref to reffable object, such as query or filter
  if (!toPath) return to.ref(fromPath);
  var fromSegments = fromPath.split('.');
  var toSegments = toPath.split('.');
  if (fromSegments.length < 2) {
    throw new Error('ref must be performed under a collection ' +
      'and document id. Invalid path: ' + fromPath);
  }
  this._ref(fromSegments, toSegments, options);
  return this.scope(fromPath);
};

Model.prototype._ref = function(fromSegments, toSegments, options) {
  this.root._refs.remove(fromSegments);
  this.root._refLists.remove(fromSegments);
  var value = this._get(toSegments);
  this._set(fromSegments, value);
  var ref = new Ref(fromSegments, toSegments, options);
  this.root._refs.add(ref);
};

Model.prototype.removeRef = function(subpath) {
  var segments = this._splitPath(subpath);
  this._removeRef(segments);
};
Model.prototype._removeRef = function(segments) {
  this.root._refs.remove(segments);
  this.root._refLists.remove(segments);
  this._del(segments);
};

Model.prototype.removeAllRefs = function(subpath) {
  var segments = this._splitPath(subpath);
  this._removeAllRefs(segments);
};
Model.prototype._removeAllRefs = function(segments) {
  this.root._refs.removeAll(segments);
  this.root._refLists.removeAll(segments);
};

Model.prototype.dereference = function(subpath) {
  var segments = this._splitPath(subpath);
  return this._dereference(segments).join('.');
};

Model.prototype._dereference = function(segments, forArrayMutator, ignore) {
  if (segments.length === 0) return segments;
  var doAgain;
  do {
    var refsNode = this.root._refs.fromMap;
    var refListsNode = this.root._refLists.fromMap;
    doAgain = false;
    for (var i = 0, len = segments.length; i < len; i++) {
      // @TODO: resolve type for Segments
      var segment = segments[i] as string;

      refsNode = refsNode && refsNode.children && refsNode.children.values[segment];
      var ref = refsNode && refsNode.listener;
      if (ref) {
        var remaining = segments.slice(i + 1);
        segments = ref.toSegments.concat(remaining);
        doAgain = true;
        break;
      }

      refListsNode = refListsNode && refListsNode.children && refListsNode.children.values[segment];
      var refList = refListsNode && refListsNode.listener;
      if (refList && refList !== ignore) {
        var belowDescendant = i + 2 < len;
        var belowChild = i + 1 < len;
        if (!(belowDescendant || forArrayMutator && belowChild)) continue;
        segments = refList.dereference(segments, i);
        doAgain = true;
        break;
      }
    }
  } while (doAgain);
  // If a dereference fails, return a path that will result in a null value
  // instead of a path to everything in the model
  if (segments.length === 0) return ['$null'];
  return segments;
};

function noopDereference(segments) {
  return segments;
}

export class Ref {
  fromSegments: Segments;
  toSegments: Segments;
  updateIndices: boolean;

  constructor(fromSegments: Segments, toSegments: Segments, options?: RefOptions) {
    this.fromSegments = fromSegments;
    this.toSegments = toSegments;
    this.updateIndices = options && options.updateIndices;
  }
}

export class Refs {
  fromMap: EventMapTree;
  toListeners: EventListenerTree;

  constructor() {
    this.fromMap = new EventMapTree();
    this.toListeners = new EventListenerTree();
  }

  _removeInputListeners(ref: Ref) {
    this.toListeners.removeListener(ref.toSegments, ref);
  };
  
  add(ref) {
    this.fromMap.setListener(ref.fromSegments, ref);
    this.toListeners.addListener(ref.toSegments, ref);
  };
  
  remove(segments) {
    var ref = this.fromMap.deleteListener(segments);
    if (!ref) return;
    this.toListeners.removeListener(ref.toSegments, ref);
  };
  
  removeAll(segments) {
    var node = this.fromMap.deleteAllListeners(segments);
    if (node) {
      node.forEach(node => this._removeInputListeners(node));
    }
  };
  
  toJSON() {
    var out = [];
    this.fromMap.forEach(function(ref) {
      var from = ref.fromSegments.join('.');
      var to = ref.toSegments.join('.');
      out.push([from, to]);
    });
    return out;
  };
}
