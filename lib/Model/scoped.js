var racer = require('../racer');
var Model = require('./index');

racer.on('Model:init', function(model) {
  model._root = model;
});

/**
 * Create a model object scoped to a particular path.
 * Example:
 *     var user = model.at('users.1');
 *     user.set('username', 'brian');
 *     user.on('push', 'todos', function (todo) {
 *       // ...
 *     });
 *
 *  @param {String} segment
 *  @param {Boolean} absolute
 *  @return {Model} a scoped model
 *  @api public
 */
Model.prototype.at = function at(segment, absolute) {
  var at = this._at;
  var val = (at && !absolute) ?
    (segment === '') ?
      at :
      at + '.' + segment :
    segment.toString();
  return Object.create(this, {_at: {value: val}});
};

Model.prototype.root = function root() {
  return Object.create(this, {_at: {value: null}});
};

/**
 * Returns a model scope that is a number of levels above the current scoped
 * path. Number of levels defaults to 1, so this method called without
 * arguments returns the model scope's parent model scope.
 *
 * @optional @param {Number} levels
 * @return {Model} a scoped model
 */
Model.prototype.parent = function parent(levels) {
  if (!levels) levels = 1;
  var at = this._at;
  if (!at) return this;
  var segments = at.split('.');
  return this.at(segments.slice(0, segments.length - levels).join('.'), true);
};

/**
 * Returns the path equivalent to the path of the current scoped model plus
 * the suffix path `rest`
 *
 * @optional @param {String} rest
 * @return {String} absolute path
 * @api public
 */
Model.prototype.path = function path(rest) {
  var at = this._at;
  if (at) {
    if (rest) return at + '.' + rest;
    return at;
  }
  return rest || '';
};

/**
 * Returns the last property segment of the current model scope path
 *
 * @optional @param {String} path
 * @return {String}
 */
Model.prototype.leaf = function leaf(path) {
  if (!path) path = this._at || '';
  var i = path.lastIndexOf('.');
  return path.substr(i+1);
};
