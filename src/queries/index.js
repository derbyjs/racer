var QueryBuilder = require('./QueryBuilder')
  , mixinModel = require('./query.Model')
  , mixinStore = __dirname + '/query.Store';

exports = module.exports = plugin;

exports.useWith = { server: true, browser: true };
exports.decorate = 'racer';

function plugin (racer) {
  racer.query = function query (namespace, queryParams) {
    queryParams || (queryParams = {});
    queryParams.from = namespace;
    return new QueryBuilder(queryParams);
  };

  ['findOne', 'find'].forEach( function (type) {
    racer[type] = function (namespace, queryParams) {
      queryParams || (queryParams = {});
      queryParams.from = namespace;
      queryParams.type = type;
      return new QueryBuilder(queryParams);
    };
  });

  racer.mixin(mixinModel, mixinStore);
};
