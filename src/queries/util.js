var QueryBuilder = require('./QueryBuilder')
  , PRIVATE_COLLECTION = '_$queries';

exports.privateQueryPath = privateQueryPath;
exports.privateQueryResultPointerPath = privateQueryResultPointerPath;
exports.privateQueryResultAliasPath = privateQueryResultAliasPath;

function privateQueryPath (queryJson, pathSuffix) {
  var queryHash = QueryBuilder.hash(queryJson)
    , path = PRIVATE_COLLECTION + '.' + queryHash;
  if (pathSuffix) path += '.' + pathSuffix;
  return path;
}

function privateQueryResultPointerPath (queryJson) {
  var pathSuffix = (queryJson.type === 'findOne')
                 ? 'resultId'
                 : 'resultIds';
  return privateQueryPath(queryJson, pathSuffix);
}

function privateQueryResultAliasPath (queryJson) {
  var pathSuffix = (queryJson.type === 'findOne')
                 ? 'result'
                 : 'results';
  return privateQueryPath(queryJson, pathSuffix);
}
