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

var __sort__ = proto.sort;
proto.sort = function (sortSpec) {
  if (typeof sortSpec === 'function') {
    this._comparator = sortSpec;
    return this;
  }
  // else sortSpec === ['fieldA', 'asc', 'fieldB', 'desc', ...]
  return __sort__.call(this, sortSpec);
};

/**
 * Registers, executes, and sets up listeners for a model query.
 *
 * @return {Model} a scoped model scoped to a refList
 * @api public
 */
proto.run = function () {
  // Lazy-assign default query type of 'find'
  if (!this.type) this.type = 'find';

  // syncRun is also called by the Query Model Scope on dependency changes
  var model = this._model
    , domain = model.get(this.ns);
  if (this.filterFn) domain = filterDomain(domain, this.filterFn);

  // TODO Register the transform, so it can be cleaned up when we no longer
  // need it

  var queryJson = this.toJSON()
    , memoryQuery = this.memoryQuery = new MemoryQuery(queryJson)
    , result = memoryQuery.syncRun(domain)
    , comparator = this.comparator;
  if (comparator) result = result.sort(comparator);

  // TODO queryId here will not be unique once we introduct ad hoc filter
  // functions
  var queryId = QueryBuilder.hash(queryJson)
    , scopedModel = setupQueryModelScope(model, memoryQuery, queryId, result);
  return scopedModel;
};

proto.filterTest = function (doc, ns) {
  if (ns !== this.ns) return false;
  var filterFn = this.filterFn;
  if (filterFn && ! filterFn(doc)) return false;
  return this.memoryQuery.filterTest(doc, ns);
};
