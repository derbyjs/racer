import { ChildModel, Model } from './Model';
import type { Path, PathLike } from '../types';
import { ModelData } from './collections';

exports.mixin = {};

declare module './Model' {
  interface Model<T> {
    /**
     * Returns a ChildModel scoped to the root path.
     */
    at(): ChildModel<T>;
    
    /**
     * Returns a ChildModel scoped to a relative subpath under this model's path.
     *
     * @typeParam S - type of data at subpath
     * @param subpath
     */
    at<S = unknown>(subpath: PathLike): ChildModel<S>;

    /**
     * Check if subpath is a PathLike
     * 
     * @param subpath 
     * @returns boolean
     */
    isPath(subpath: PathLike): boolean;
    
    leaf(path: string): string;
    
    /**
     * Get the parent {levels} up from current model or root model
     * @param levels - number of levels to traverse the tree
     * @returns parent or root model
     */
    parent(levels?: number): Model;
    
    /**
     * Get full path to given subpath
     * 
     * @param subpath - PathLike subpath
     */
    path(subpath?: PathLike): string;

    /**
     * Returns a ChildModel scoped to the root path.
     * 
     * @returns ChildModel
     */
    scope(): ChildModel<ModelData>;

    /**
     * Returns a ChildModel scoped to an absolute path.
     *
     * @typeParam S - Type of data at subpath
     * @param subpath - Path of GhildModel to scope to
     * @returns ChildModel
     */
    scope<S = unknown>(subpath: Path): ChildModel<S>;
    
    /** @private */
    _splitPath(subpath: PathLike): string[];
  }
}

Model.prototype._splitPath = function(subpath?: PathLike): string[] {
  var path = this.path(subpath);
  return (path && path.split('.')) || [];
};

/**
 * Returns the path equivalent to the path of the current scoped model plus
 * (optionally) a suffix subpath
 *
 * @optional @param {String} subpath
 * @return {String} absolute path
 * @api public
 */
Model.prototype.path = function(subpath?: PathLike): string {
  if (subpath == null || subpath === '') return (this._at) ? this._at : '';
  if (typeof subpath === 'string' || typeof subpath === 'number') {
    return (this._at) ? this._at + '.' + subpath : '' + subpath;
  }
  if (typeof subpath.path === 'function') return subpath.path();
};

Model.prototype.isPath = function(subpath?: PathLike): boolean {
  return this.path(subpath) != null;
};

Model.prototype.scope = function<S>(path?: PathLike): ChildModel<S> {
  if (arguments.length > 1) {
    for (var i = 1; i < arguments.length; i++) {
      path = path + '.' + arguments[i];
    }
  }
  return createScoped(this, path);
};

/**
 * Create a model object scoped to a particular path.
 * Example:
 *     var user = model.at('users.1');
 *     user.set('username', 'brian');
 *     user.on('push', 'todos', function(todo) {
 *       // ...
 *     });
 *
 *  @param {String} segment
 *  @return {Model} a scoped model
 *  @api public
 */
Model.prototype.at = function(subpath?: Path) {
  if (arguments.length > 1) {
    for (var i = 1; i < arguments.length; i++) {
      subpath = subpath + '.' + arguments[i];
    }
  }
  var path = this.path(subpath);
  return createScoped(this, path);
};

function createScoped(model, path) {
  var scoped = model._child();
  scoped._at = path;
  return scoped;
}

/**
 * Returns a model scope that is a number of levels above the current scoped
 * path. Number of levels defaults to 1, so this method called without
 * arguments returns the model scope's parent model scope.
 *
 * @optional @param {Number} levels
 * @return {Model} a scoped model
 */
Model.prototype.parent = function(levels) {
  if (levels == null) levels = 1;
  var segments = this._splitPath();
  var len = Math.max(0, segments.length - levels);
  var path = segments.slice(0, len).join('.');
  return this.scope(path);
};

/**
 * Returns the last property segment of the current model scope path
 *
 * @optional @param {String} path
 * @return {String}
 */
Model.prototype.leaf = function(path) {
  if (!path) path = this.path();
  var i = path.lastIndexOf('.');
  return path.slice(i + 1);
};
