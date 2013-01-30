var QueryBuilder = require('./QueryBuilder')
  , MemoryQuery = require('./MemoryQuery')
  , setupQueryModelScope = require('./scope')
  , filterDomain = require('../../computed/filter').filterDomain
  , bundledFunction = require('../../bundle/util').bundledFunction
  , unbundledFunction = require('../../bundle/util').unbundledFunction
  , Model = require('../../Model')
  ;

module.exports = TransformBuilder;

function TransformBuilder (model, source) {
  QueryBuilder.call(this);
  this._model = model;
  this.from(source);

  // This is an array of paths that this Transformation (i.e., filter) depends
  // on. Filters will depend on paths if we use filter against parameters that
  // are paths pointing to data that can change. e.g.,
  //
  //   model.filter(ns).where(field).equals(model.at('_dependency'))
  //
  // In this case, this.dependencies == ['_dependency']
  this.dependencies = [];
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
  return this.model().get();
};

TransformBuilder.prototype.model = function () {
  var scopedModel = this.scopedModel;
  if (! scopedModel) {
    scopedModel = this.scopedModel = this._genScopedModel();
    var model = this._model;

    // For server-side bundling
    if (model._onCreateFilter) {
      model._onCreateFilter(this);
    }
  }
  return scopedModel;
};

TransformBuilder.prototype.path = function () {
  return this.model().path();
};

// Default query type of 'find'
TransformBuilder.prototype.type = 'find';

TransformBuilder.prototype._genScopedModel = function () {
  // syncRun is also called by the Query Model Scope on dependency changes
  var model = this._model
    , domain = model.get(this.ns)
    , filterFn = this.filterFn;

  // TODO Register the transform, so it can be cleaned up when we no longer
  // need it

  var queryJson = QueryBuilder.prototype.toJSON.call(this)
    , comparator = this._comparator
    , memoryQuery = this.memoryQuery = new MemoryQuery(queryJson, model)
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
  return setupQueryModelScope(model, memoryQuery, queryId, result, this.dependencies);
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

QueryBuilder.queryMethods.forEach( function (method) {
  var oldMethod = TransformBuilder.prototype[method];
  TransformBuilder.prototype[method] = function (val) {
    var pathToDependency;
    if (val instanceof Model) {
      pathToDependency = val.path();
      val = {$ref: pathToDependency};
    } else if (val && val.$ref) {
      pathToDependency = val.$ref;
    }
    if (pathToDependency) {
      var dependencies = this.dependencies;
      if (dependencies.indexOf(pathToDependency) === -1) {
        dependencies.push(pathToDependency);
      }
    }
    return oldMethod.call(this, val);
  }
});
