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
 * Registers, executes, and sets up listeners for a find model query.
 * @return {Model} a scoped model scoped to a refList
 */
proto.find = function find () {
  var queryJson = this.toJSON()
    , model = this._model
    , memoryQuery = new MemoryQuery(queryJson).find()
    , results = memoryQuery.syncRun(model.get(queryJson.from));
  // TODO Clean up local queries when we no longer need them
  model.registerQuery(memoryQuery, model._localQueries);
  return setupQueryModelScope(model, queryJson, results);
};

/**
 * Registers, executes, and sets up listeners for a findOne model query.
 * @return {Model} a scoped model scoped to a ref
 */
proto.findOne = function findOne () {
  var queryJson = this.toJSON()
    , model = this._model
    , memoryQuery = new MemoryQuery(queryJson).findOne()
    , result = memoryQuery.syncRun(model.get(queryJson.from));
  // TODO Clean up local queries when we no longer need them
  model.registerQuery(memoryQuery, model._localQueries);
  return setupQueryModelScope(model, queryJson, result);
}
