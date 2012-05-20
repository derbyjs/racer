var QueryBuilder = require('./QueryBuilder')
  , MemoryQuery = require('./MemoryQuery');

module.exports = ModelQueryBuilder;

function ModelQueryBuilder (params, model) {
  QueryBuilder.call(this, params);
  this._model = model;
}

ModelQueryBuilder.fromJSON = QueryBuilder._createFromJsonFn(ModelQueryBuilder);

var proto = ModelQueryBuilder.prototype = new QueryBuilder();

proto.find = function find () {
  var memory = this._model.memory
    , memoryQuery = new MemoryQuery(this.toJSON());
  memoryQuery.find();
  return memoryQuery.syncRun(memory.get());
};

proto.findOne = function findOne () {
  var memory = this._model.memory
    , memoryQuery = new MemoryQuery(this.toJSON());
  memoryQuery.findOne();
  return memoryQuery.syncRun(memory.get());
};
