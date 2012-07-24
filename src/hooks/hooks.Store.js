var eventRegExp = require('../path').eventRegExp
  , transaction = require('../transaction')
  , createMiddleware = require('../middleware')
  ;

module.exports = {
  type: 'Store'
, events: {
    init: function (store) {
    }
  , middleware: function (store, middleware) {
      middleware.beforeAccessControl = createMiddleware();
      middleware.afterDb = createMiddleware();
    }
  }

, proto: {
    beforeAccessControl: function (mutator, path, callback) {
      var fn = gatedMiddleware(mutator, path, function (req, res, next) {
        var txn = req.data
          , caller = {session: req.session};
        callback.call(caller, txn, req.origDoc, next);
      });
      this.middleware.beforeAccessControl.add(fn);
      return this;
    }
  , afterDb: function (mutator, path, callback) {
      var fn = gatedMiddleware(mutator, path, function (req, res, next) {
        var txn = req.data
          , caller = {session: req.session};
        callback.call(caller, txn, req.origDoc, next);
      });
      this.middleware.afterDb.add(fn);
      return this;
    }
  }
}

// TODO Re-factor: All of this is very similar to accessControl writeGuard
function gatedMiddleware (mutator, path, callback) {
  var regexp = eventRegExp(path);
  return function (req, res, next) {
    var txn = req.data
      , method;
    if (mutator !== '*') {
      method = transaction.getMethod(txn);
      if (mutator !== method) return next();
    }
    var path = transaction.getPath(txn);
    if (! regexp.test(path)) return next();

    callback(req, res, next);
  };
}
