var TransformBuilder = require('../descriptor/query/TransformBuilder');

module.exports = {
  type: 'Model'
, server: __dirname + '/computed.server'
, events: {
    init: function (model) {
      model._filtersToBundle = [];
    }

  , bundle: function (model) {
      var onLoad = model._onLoad
        , filtersToBundle = model._filtersToBundle;
      for (var i = 0, l = filtersToBundle.length; i < l; i++) {
        onLoad.push( filtersToBundle[i] );
      }
    }
  }
, proto: {
    /**
     * @param {String|Model} source
     * @param {Object|Function} filterSpec
     * @return {TransformBuilder}
     */
    filter: function (source, filterSpec) {
      var builder = new TransformBuilder(this._root, source.path ? source.path() : source);
      if (filterSpec) builder.filter(filterSpec);
      return builder;
    }

    /**
     * @param {String|Model} source
     * @param {Array|Function} sortParams
     * @return {TransformBuilder}
     */
  , sort: function (source, sortParams) {
      var builder = new TransformBuilder(this._root, source.path ? source.path() : source);
      builder.sort(sortParams);
      return builder;
    }

  , _loadFilter: function (builderJson) {
      var builder = TransformBuilder.fromJson(this, builderJson);

      // This creates the scoped model associated with the filter. This model
      // is scoped to path "_$queries.<filter-id>"
      builder.model();
    }
  }
};

var mixinProto = module.exports.proto;

for (var k in mixinProto) {
  scopeFriendly(mixinProto, k);
}

/**
 * @param {Object} object
 * @param {String} method
 */
function scopeFriendly (object, method) {
  var old = object[method];
  object[method] = function (source, params) {
    var at = this._at;
    if (at) {
      if (typeof source === 'string') {
        source = at + '.' + source;
      } else {
        params = source;
        source = at;
      }
    }
    return old.call(this, source, params);
  }
}

