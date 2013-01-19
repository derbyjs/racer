var QueryBuilder = require('./QueryBuilder')
  , MemoryQuery = require('./MemoryQuery')
  , setupQueryModelScope = require('./scope')
  , filterDomain = require('../../computed/filter').filterDomain
  , bundledFunction = require('../../bundle/util').bundledFunction
  , unbundledFunction = require('../../bundle/util').unbundledFunction;
  ;

module.exports = TransformBuilder;

function TransformBuilder (model, source) {
  QueryBuilder.call(this);
  this._model = model;
  this.from(source);
}

var fromJson = QueryBuilder._createFromJsonFn(TransformBuilder);

TransformBuilder.fromJson = function (model, source) {
  var filterFn = source.filter;
  delete source.filter;
  var builder = fromJson(source);
  builder._model = model;
  if (filterFn) {
    filterFn = unbundledFunction(filterFn);
    builder.filter(filterFn);
  }
  return builder;
};

TransformBuilder.prototype = new QueryBuilder();

TransformBuilder.prototype.filter = function (filterSpec) {
  var filterFn;
  if (typeof filterSpec === 'function') {
    this.filterFn = filterSpec;
  } else if (filterSpec.constructor == Object) {
    this.query(filterSpec);
  }
  return this;
};

var __sort__ = TransformBuilder.prototype.sort;
TransformBuilder.prototype.sort = function (sortSpec) {
  if (typeof sortSpec === 'function') {
    this._comparator = sortSpec;
    return this;
  }
  // else sortSpec === ['fieldA', 'asc', 'fieldB', 'desc', ...]
  return __sort__.call(this, sortSpec);
};

// Quack like a Model (delegates to Model#get and Model#path)

/**
 * Registers, executes, and sets up listeners for a model query, the first time
 * this is called. Subsequent calls just return the cached scoped model
 * representing the filter result.
 *
 * @return {Model} a scoped model scoped to a refList
 * @api public
 */
TransformBuilder.prototype.get = function () {
  var scopedModel = this.scopedModel ||
                   (this.scopedModel = this._genScopedModel());
  return scopedModel.get();
};

TransformBuilder.prototype.path = function () {
  var scopedModel = this.scopedModel ||
                   (this.scopedModel = this._genScopedModel());
  return scopedModel.path();
};

TransformBuilder.prototype._genScopedModel = function () {
  // Lazy-assign default query type of 'find'
  if (!this.type) this.type = 'find';

  // syncRun is also called by the Query Model Scope on dependency changes
  var model = this._model
    , domain = model.get(this.ns)
    , filterFn = this.filterFn;

  // TODO Register the transform, so it can be cleaned up when we no longer
  // need it

  var queryJson = QueryBuilder.prototype.toJSON.call(this)
    , comparator = this._comparator
    , memoryQuery = this.memoryQuery = new MemoryQuery(queryJson)
    ;
  if (filterFn) {
    var oldSyncRun = memoryQuery.syncRun
      , oldFilterTest = memoryQuery.filterTest;
    memoryQuery.syncRun = function (searchSpace) {
      searchSpace = filterDomain(searchSpace, function (v, k) {
        return filterFn(v, k, model);
      });
      return oldSyncRun.call(this, searchSpace);
    };
    memoryQuery.filterTest = function (doc, ns) {
      // TODO Replace null with key or index in filterFn call
      return oldFilterTest.call(this, doc, ns) && filterFn(doc, null, model);
    };
  }
  if (comparator) memoryQuery.sort(comparator);
  var result = memoryQuery.syncRun(domain);
  var queryId = QueryBuilder.hash(queryJson, filterFn);
  return setupQueryModelScope(model, memoryQuery, queryId, result);
};

TransformBuilder.prototype.toJSON = function () {
  var json = QueryBuilder.prototype.toJSON.call(this);
  if (this.filterFn) {
    json.filter = bundledFunction(this.filterFn);
  }
  return json;
};

// TransformBuilder.prototype.filterTest = function (doc, ns) {
//   if (ns !== this.ns) return false;
//   var filterFn = this.filterFn;
//   if (filterFn && ! filterFn(doc)) return false;
//   return this.memoryQuery.filterTest(doc, ns);
// };
