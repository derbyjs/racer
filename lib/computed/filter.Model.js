var TransformBuilder = require('../descriptor/query/TransformBuilder');

module.exports = {
  type: 'Model'
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

