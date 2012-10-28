var eventRegExp = require('../path').eventRegExp
  , transaction = require('../transaction')
  , applyTxnToDoc = transaction.applyTxnToDoc
  , createMiddleware = require('../middleware')
  , deepCopy = require('../util').deepCopy
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
    beforeAccessControl: function (mutator, path, cb) {
      var fn = gatedMiddleware(mutator, path, function (req, res, next) {
        var txn = req.data
          , caller = {session: req.session};
        cb.call(caller, txn, req.origDoc, next);
      });
      this.middleware.beforeAccessControl.add(fn);
      return this;
    }
  , afterDb: function (mutator, path, cb) {
      var fn = gatedMiddleware(mutator, path, function (req, res, next) {
        var txn = req.data
          , arity = cb.length
          , oldDoc = req.origDoc
          , caller = {session: req.session};
        if (arity === 4) {
          // TOOD: Check other places in code where applyTxnToDoc is used and see
          // if we deepCopy in all of those places
          var newDoc = applyTxnToDoc(txn, deepCopy(oldDoc));
          cb.call(caller, txn, newDoc, oldDoc, next);
        } else if (arity === 3) {
          cb.call(caller, txn, oldDoc, next);
        } else {
          throw new Error('Must have 3 to 4 arguments');
        }
      });
      this.middleware.afterDb.add(fn);
      return this;
    }
  }
}

// TODO Re-factor: All of this is very similar to accessControl writeGuard
function gatedMiddleware (mutator, path, cb) {
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

    cb(req, res, next);
  };
}
