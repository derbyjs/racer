var uglify = require('uglify-js')
  , isProduction = require('../util').isProduction
  , cbs = {};

module.exports = {
  _onCreateRef: function (method, from, to, key, get) {
    var args = [method, from, to];
    if (key) args.push(key);
    this._refsToBundle.push([from, get, args]);
  }

, _onCreateFn: function (path, inputs, callback) {
    var cb = callback.toString();
    if (isProduction) {
      if (cb in cbs) {
        cb = cbs[cb];
      } else {
        // Uglify can't parse a naked function. Executing it allows Uglify to
        // parse it properly
        var uglified = uglify('(' + cb + ')()');
        cbs[cb] = uglified.slice(1, -3);
      }
    }

    var fnsToBundle = this._fnsToBundle
      , len = fnsToBundle.push(['fn', path].concat(inputs).concat([cb]));
    return function () {
      delete fnsToBundle[len-1];
    };
  }
};
