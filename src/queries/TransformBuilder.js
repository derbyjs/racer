// TODO Remove this file
var QueryBuilder = require('./QueryBuilder')
  , MemoryQuery = require('./MemoryQuery')
  , setupQueryModelScope = require('./util').setupQueryModelScope
  ;

module.exports = TransformBuilder;

function TransformBuilder (model, source) {
  QueryBuilder.call(this);
  this._model = model;
  this.from(source);
}

TransformBuilder.fromJSON = QueryBuilder._createFromJsonFn(TransformBuilder);

var proto = TransformBuilder.prototype = new QueryBuilder();

proto.filter = function (filterSpec) {
  var filterFn;
  if (typeof filterSpec === 'function') {
    this.filterFn = filterSpec;
  } else if (filterSpec.constructor == Object) {
    this.query(filterSpec);
  }
  return this;
};

/**
 * Registers, executes, and sets up listeners for a model query.
 *
 * @return {Model} a scoped model scoped to a refList
 * @api public
 */
proto.run = function () {
  var queryJson = this.toJSON();
  // Lazy-assign default query type of 'find'
  if (!queryJson.type) queryJson.type = 'find';

  var model = this._model
    , domain = model.get(queryJson.from);
  if (this.filterFn) domain = filterDomain(domain, this.filterFn);

  // TODO Register the transform, so it can be cleaned up when we no longer
  // need it

  var memoryQuery = new MemoryQuery(queryJson)
    , result = memoryQuery.syncRun(domain)
      // TODO queryId here will not be unique once we introduct ad hoc filter
      // functions
    , queryId = QueryBuilder.hash(queryJson);
  var scopedModel = setupQueryModelScope(model, memoryQuery, queryId, result);
  return scopedModel;
};
