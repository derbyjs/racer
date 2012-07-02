var util = require('./index')
  , merge = util.merge;

module.exports =
util.speculative = {
  createObject: function () { return {$spec: true}; }

, createArray: function () {
    var obj = [];
    obj.$spec = true;
    return obj;
  }

, create: function (proto) {
    if (proto.$spec) return proto;

    if (Array.isArray(proto)) {
      // TODO Slicing is obviously going to be inefficient on large arrays, but
      // inheriting from arrays is problematic. Eventually it would be good to
      // implement something faster in browsers that could support it. See:
      // http://perfectionkills.com/how-ecmascript-5-still-does-not-allow-to-subclass-an-array/#wrappers_prototype_chain_injection
      var obj = proto.slice();
      obj.$spec = true;
      return obj
    }

    return Object.create(proto, { $spec: { value: true } });
  }

, clone: function (proto) {
    if (Array.isArray(proto)) {
      var obj = proto.slice();
      obj.$spec = true;
      return obj;
    }

    return merge({}, proto);
  }

, isSpeculative: function (obj) {
    return obj && obj.$spec;
  }

, identifier: '$spec' // Used in tests
};
