import { type Segments } from './types';
import { Doc } from './Doc';
import { Model, RootModel } from './Model';
import { JSONObject } from 'sharedb/lib/sharedb';
import { VerifyJsonWebKeyInput } from 'crypto';
import { Path, ReadonlyDeep, ShallowCopiedValue } from '../types';
var LocalDoc = require('./LocalDoc');
var util = require('../util');

export class ModelCollections {
  docs: Record<string, any>;
}

/** Root model data */
export class ModelData {
  [collectionName: string]: CollectionData<JSONObject>;
}

class DocMap {
  [id: string]: Doc;
}

/** Dictionary of document id to document data */
export class CollectionData<T extends JSONObject> {
  [id: string]: T;
}

declare module './Model' {
  interface RootModel {
    collections: ModelCollections;
    data: ModelData;
  }
  interface Model<T> {
    destroy(subpath?: string): void;

    /**
     * Gets the value located at this model's path or a relative subpath.
     *
     * If no value exists at the path, this returns `undefined`.
     *
     * _Note:_ The value is returned by reference, and object values should not
     * be directly modified - use the Model mutator methods instead. The
     * TypeScript compiler will enforce no direct modifications, but there are
     * no runtime guards, which means JavaScript source code could still
     * improperly make direct modifications.
     *
     * @param subpath
     */
    get<S>(subpath: Path): ReadonlyDeep<S> | undefined;
    get(): ReadonlyDeep<T> | undefined;
    
    getCollection(collectionName: string): Collection<JSONObject>;
    
    /**
     * Gets a shallow copy of the value located at this model's path or a relative
     * subpath.
     *
     * If no value exists at the path, this returns `undefined`.
     *
     * @param subpath
     */
    getCopy<S>(subpath: Path): ShallowCopiedValue<S> | undefined;
    getCopy(): ShallowCopiedValue<T> | undefined;

    /**
     * Gets a deep copy of the value located at this model's path or a relative
     * subpath.
     *
     * If no value exists at the path, this returns `undefined`.
     *
     * @param subpath
     */
    getDeepCopy<S>(subpath: Path): S | undefined;
    getDeepCopy(): T | undefined;

    getDoc(collecitonName: string, id: string): any | undefined;
    getOrCreateCollection(name: string): Collection;
    getOrCreateDoc(collectionName: string, id: string, data: any);

    _get(segments: Segments): any;
    _getCopy(segments: Segments): any;
    _getDeepCopy(segments: Segments): any;
  }
}

Model.INITS.push(function(model) {
  model.root.collections = new ModelCollections();
  model.root.data = new ModelData();
});

Model.prototype.getCollection = function(collectionName) {
  return this.root.collections[collectionName];
};

Model.prototype.getDoc = function(collectionName, id) {
  var collection = this.root.collections[collectionName];
  return collection && collection.docs[id];
};

Model.prototype.get = function<S>(subpath?: Path) {
  var segments = this._splitPath(subpath);
  return this._get(segments) as ReadonlyDeep<S>;
};

Model.prototype._get = function(segments) {
  return util.lookup(segments, this.root.data);
};

Model.prototype.getCopy = function<S>(subpath?: Path) {
  var segments = this._splitPath(subpath);
  return this._getCopy(segments) as ReadonlyDeep<S>;
};

Model.prototype._getCopy = function(segments) {
  var value = this._get(segments);
  return util.copy(value);
};

Model.prototype.getDeepCopy = function<S>(subpath?: Path) {
  var segments = this._splitPath(subpath);
  return this._getDeepCopy(segments) as S;
};

Model.prototype._getDeepCopy = function(segments) {
  var value = this._get(segments);
  return util.deepCopy(value);
};

Model.prototype.getOrCreateCollection = function(name) {
  var collection = this.root.collections[name];
  if (collection) return collection;
  var Doc = this._getDocConstructor(name);
  collection = new Collection(this.root, name, Doc);
  this.root.collections[name] = collection;
  return collection;
};

Model.prototype._getDocConstructor = function(name: string) {
  // Only create local documents. This is overriden in ./connection.js, so that
  // the RemoteDoc behavior can be selectively included
  return LocalDoc;
};

/**
 * Returns an existing document with id in a collection. If the document does
 * not exist, then creates the document with id in a collection and returns the
 * new document.
 * @param {String} collectionName
 * @param {String} id
 * @param {Object} [data] data to create if doc with id does not exist in collection
 */
Model.prototype.getOrCreateDoc = function(collectionName, id, data) {
  var collection = this.getOrCreateCollection(collectionName);
  return collection.getOrCreateDoc(id, data);
};

/**
 * @param {String} subpath
 */
Model.prototype.destroy = function(subpath) {
  var segments = this._splitPath(subpath);
  // Silently remove all types of listeners within subpath
  var silentModel = this.silent();
  silentModel._removeAllListeners(null, segments);
  silentModel._removeAllRefs(segments);
  silentModel._stopAll(segments);
  silentModel._removeAllFilters(segments);
  // Remove listeners created within the model's eventContext and remove the
  // reference to the eventContext
  silentModel.removeContextListeners();
  // Silently remove all model data within subpath
  if (segments.length === 0) {
    this.root.collections = new ModelCollections();
    // Delete each property of data instead of creating a new object so that
    // it is possible to continue using a reference to the original data object
    var data = this.root.data;
    for (var key in data) {
      delete data[key];
    }
  } else if (segments.length === 1) {
    var collection = this.getCollection(segments[0]);
    collection && collection.destroy();
  } else {
    silentModel._del(segments);
  }
};

export class Collection<T extends JSONObject = {}> {
  model: RootModel;
  name: string;
  size: number;
  docs: DocMap;
  data: CollectionData<T>;
  Doc: typeof Doc;

  constructor(model: RootModel, name: string, docClass: typeof Doc) {
    this.model = model;
    this.name = name;
    this.Doc = docClass;
    this.size = 0;
    this.docs = new DocMap();
    this.data = model.data[name] = new CollectionData<T>();
  }

  /**
   * Adds a document with `id` and `data` to `this` Collection.
   * @param {String} id
   * @param {Object} data
   * @return {LocalDoc|RemoteDoc} doc
   */
  add(id, data) {
    var doc = new this.Doc(this.model, this.name, id, data, this);
    this.docs[id] = doc;
    return doc;
  };
  
  destroy() {
    delete this.model.collections[this.name];
    delete this.model.data[this.name];
  };
  
  getOrCreateDoc(id, data) {
    var doc = this.docs[id];
    if (doc) return doc;
    this.size++;
    return this.add(id, data);
  };

  /**
   * Removes the document with `id` from `this` Collection. If there are no more
   * documents in the Collection after the given document is removed, then this
   * destroys the Collection.
   *
   * @param {String} id
   */
  remove(id: string) {
    if (!this.docs[id]) return;
    this.size--;
    if (this.size > 0) {
      delete this.docs[id];
      delete this.data[id];
    } else {
      this.destroy();
    }
  }
};
