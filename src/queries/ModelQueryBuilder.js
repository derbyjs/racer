var QueryBuilder = require('./QueryBuilder')
  , MemoryQuery = require('./MemoryQuery')
  , setupQueryModelScope = require('./util').setupQueryModelScope
  ;

module.exports = ModelQueryBuilder;

function ModelQueryBuilder (params, model) {
  QueryBuilder.call(this, params);
  this._model = model;
}

ModelQueryBuilder.fromJSON = QueryBuilder._createFromJsonFn(ModelQueryBuilder);

var proto = ModelQueryBuilder.prototype = new QueryBuilder();

/**
 * Registers, executes, and sets up listeners for a model query.
 * @return {Model} a scoped model scoped to a refList
 */
proto.find = function find () {
  var queryJson = this.toJSON();
  // Lazy-assign default query type of 'find'
  if (!queryJson.type) queryJson.type = 'find';

  var model = this._model
    , memoryQuery = new MemoryQuery(queryJson)
    , result = memoryQuery.syncRun(model.get(queryJson.from));
  // TODO Clean up local queries when we no longer need them
  model.registerQuery(memoryQuery, model._localQueries);
  return setupQueryModelScope(model, queryJson, result);
};
