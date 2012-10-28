var cbs = {}
  , bundledFunction = require('../bundle/util').bundledFunction;

module.exports = {
  _onCreateRef: function (method, from, to, key, get) {
    var args = [method, from, to];
    if (key) args.push(key);
    this._refsToBundle.push([from, get, args]);
  }

, _onCreateComputedRef: function(from, to, get) {
    var args = ['_loadComputedRef', from, to];
    this._refsToBundle.push([from, get, args]);
  }

, _onCreateFn: function (path, inputs, callback) {
    var fnsToBundle = this._fnsToBundle
      , len = fnsToBundle.push(['fn', path].concat(inputs).concat([bundledFunction(callback)]));

    return function () {
      delete fnsToBundle[len-1];
    };
  }
};
