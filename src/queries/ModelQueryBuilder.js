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
 * @return {Model} a scoped model scoped to 
 */
proto.find = function find () {
  var queryJson = this.toJSON()
    , model = this._model
    , memoryQuery = new MemoryQuery(queryJson).find()
    , results = memoryQuery.syncRun(model.get(queryJson.from));
  // TODO Clean up local queries when we no longer need them
  model.registerQuery(memoryQuery, model._localQueries);
  // Returns a scoped model
  return setupQueryModelScope(model, queryJson, results);
};

// TODO findOne should return a scoped model
proto.findOne = function findOne () {
  var queryJson = this.toJSON()
    , scopedPath = resultRefPath(queryJson)
    , memoryQuery = new MemoryQuery(queryJson).findOne()
    , results = memoryQuery.syncRun(model.get(queryJson.from));
  return results;
}
