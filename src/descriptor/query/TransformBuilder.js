var QueryBuilder = require('./QueryBuilder')
  , MemoryQuery = require('./MemoryQuery')
  , setupQueryModelScope = require('./scope')
  , filterDomain = require('../../computed/filter').filterDomain
  ;

module.exports = TransformBuilder;

function TransformBuilder (model, source) {
  QueryBuilder.call(this);
  this._model = model;
  this.from(source);
}

var fromJson = QueryBuilder._createFromJsonFn(TransformBuilder);
TransformBuilder.fromJson = function (model, source) {
  var builder = fromJson(source);
  builder._model = model;
  return builder;
};

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
 * Registers, executes, and sets up listeners for a model query, the first time
 * this is called. Subsequent calls just return the cached scoped model
 * representing the filter result.
 *
 * @return {Model} a scoped model scoped to a refList
 * @api public
 */
proto.get = function () {
  var scopedModel = this.scopedModel ||
                   (this.scopedModel = this._genScopedModel());
  return scopedModel.get();
};

proto.path = function () {
  var scopedModel = this.scopedModel ||
                   (this.scopedModel = this._genScopedModel());
  return scopedModel.path();
};

proto._genScopedModel = function () {
  // Lazy-assign default query type of 'find'
  if (!this.type) this.type = 'find';

  // syncRun is also called by the Query Model Scope on dependency changes
  var model = this._model
    , domain = model.get(this.ns)
    , filterFn = this.filterFn;
  if (filterFn) domain = filterDomain(domain, filterFn);

  // TODO Register the transform, so it can be cleaned up when we no longer
  // need it

  var queryJson = this.toJSON()
    , memoryQuery = this.memoryQuery = new MemoryQuery(queryJson, filterFn)
    , comparator = this._comparator;
  if (comparator) memoryQuery.sort(comparator);
  var result = memoryQuery.syncRun(domain);
  var queryId = QueryBuilder.hash(queryJson, filterFn);
  return setupQueryModelScope(model, memoryQuery, queryId, result);
};

// proto.filterTest = function (doc, ns) {
//   if (ns !== this.ns) return false;
//   var filterFn = this.filterFn;
//   if (filterFn && ! filterFn(doc)) return false;
//   return this.memoryQuery.filterTest(doc, ns);
// };
