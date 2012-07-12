var eventRegExp = require('../path').eventRegExp
  , transaction = require('../transaction')
  , createMiddleware = require('../middleware')
  ;

exports = module.exports = {
  type: 'Store'
, events: {
    init: function (store) {
      store.accessControl = false;
      store.eachContext(function (context) {
        context.guardReadPath = createMiddleware();
        context.guardQuery    = createMiddleware();
        context.guardWrite    = createMiddleware();

        var _grp_ = context.guardReadPath;
        context.guardReadPath = function (req, res, next) {
          context.guardReadPath.add( function (req, res, next) {
            if (! store.accessControl) return next();
            if (! req.didMatchAGuard)
              return res.fail('Unauthorized: No access control declared for path ' + req.target);
            next();
          });
          context.guardReadPath = _grp_;
          context.guardReadPath(req, res, next);
        };
        context.guardReadPath.add = _grp_.add;

        var _gp_ = context.guardQuery;
        context.guardQuery = function (req, res, next) {
          context.guardQuery.add( function (req, res, next) {
            if (! store.accessControl) return next();
            var queryTuple = req.target
              , queryNs = queryTuple[0]
              , motifs = queryTuple[1]
              , matchingGuardFor = req.matchingGuardFor;
            for (var motifName in motifs) {
              if (! matchingGuardFor || !matchingGuardFor[motifName])
                return res.fail('Unauthorized: No access control declared for motif ' + motifName);
            }
            next();
          });
          context.guardQuery = _gp_;
          context.guardQuery(req, res, next);
        };
        context.guardQuery.add = _gp_.add;

        var _gw_ = context.guardWrite;
        context.guardWrite = function (req, res, next) {
          if (! store.accessControl) return next();
          context.guardWrite.add( function (req, res, next) {
            if (! req.didMatchAGuard) {
              var txn = req.data;
              return res.fail('Unauthorized: No access control declared for mutator: ' +
                transaction.getMethod(txn) + ' ' + transaction.getPath(txn)
              );
            }
            next();
          });
          context.guardWrite = _gw_;
          context.guardWrite(req, res, next);
        };
        context.guardWrite.add = _gw_.add;
      });
    }
  }
, proto: {
    /**
     * Declare access controls for reading paths and path patterns
     *
     * store.readPathAccess('users.*', function (id, next) {
     *   var session = this.session;
     *   store.get('users.' + session.userId, function (err, user) {
     *     next(user.friendIds.indexOf(id) !== -1);
     *   });
     * });
     *
     * @param {String} path representing the path pattern
     * @param {Function} callback(captures..., next)
     * @return {Store} the store for chaining
     * @api public
     */
    readPathAccess: function (path, callback) {
      var context = this.currContext;
      var fn = createPathGuard(path, callback);
      context.guardReadPath.add(fn);
      return this;
    }

    /**
     * Declare access controls for querying.
     *
     * store.queryAccess('users', 'friendsOf', function (userId) {
     *   var session = this.session;
     *   store._fetchQueryData(['users', 'friendsOf', userId]
     * });
     *
     * @param {String} ns is the collection namespace
     * @param {String} motif is the name of the query motif
     * @param {Function} callback
     * @return {Store} the store for chaining
     * @api public
     */
  , queryAccess: function (ns, motif, callback) {
      var context = this.currContext;
      var fn = createQueryGuard(ns, motif, callback);
      context.guardQuery.add(fn);
      return this;
    }

    /**
     * Declare write access controls
     * @param {String} mutator method name
     * @param {String} target path pattern (or query)
     * @param {Function} callback(captures..., txnArgs..., next)
     * @return {Store} the store for chaining
     * @api public
     */
  , writeAccess: function (mutator, target, callback) {
      var context = this.currContext;
      var fn = createWriteGuard(mutator, target, callback);
      context.guardWrite.add(fn);
      return this;
    }
  }
};

/**
 * Returns a guard function (see JSDoc inside this function for details) that
 * enables the store to guard against unauthorized access to paths that match
 * pattern. The logic that determines who has access or not is defined by callback.
 *
 * @param {String} pattern
 * @param {Function} callback
 * @return {Function}
 * @api private
 */
function createPathGuard (pattern, callback) {
  var regexp = eventRegExp(pattern);

  /**
   * Determines whether a client (represented by req.session) should be able to
   * retrieve path via Model#subscribe or Model#fetch. If the client is allowed
   * to, then next(). Otherwise res.fail('Unauthorized')
   * @param {Object} req
   * @param {String} res
   * @param {Function} next
   */
  function guard (req, res, next) {
    var session = req.session
      , path = req.target;
    if (!regexp.test(path)) return next();
    req.didMatchAGuard = true
    var captures = regexp.exec(path).slice(1)
      , caller = {session: session};
    callback.apply(caller, captures.concat([function (isAllowed) {
      if (!isAllowed) return res.fail('Unauthorized');
      return next();
    }]));
  }

  return guard;
}

function createQueryGuard (ns, motif, callback) {
  /**
   * Determines whether a client (represented by req.session) should be able to
   * retrieve the query represented by req.queryTuple via Model#subscribe or
   * Model#fetch. If the client is allowed to, then next().
   * Otherwise res.fail('Unauthorized');
   */
  function guard (req, res, next) {
    var queryTuple = req.target
      , queryNs = queryTuple[0]
      , motifs = queryTuple[1];

    if (ns !== queryNs) return next();
    var matchingMotif;
    for (var motifName in motifs) {
      if (motifName === motif) {
        matchingMotif = motifName
        break;
      }
    }
    if (! matchingMotif) return next();

    req.matchingGuardFor || (req.matchingGuardFor = {});
    req.matchingGuardFor[matchingMotif] = true;

    var args = motifs[matchingMotif];
    var caller = {session: req.session};
    callback.apply(caller, args.concat([function (isAllowed) {
      if (!isAllowed) return res.fail('Unauthorized');
      return next();
    }]));
  }
  return guard;
}

function createWriteGuard (mutator, target, callback) {
  var regexp = eventRegExp(target);

  function guard (req, res, next) {
    var txn = req.data
      , method;
    if (mutator !== '*') {
      method = transaction.getMethod(txn);
      if (mutator !== method) return next();
    }
    var path = transaction.getPath(txn);
    if (! regexp.test(path)) return next();

    req.didMatchAGuard = true;

    var captures = regexp.exec(path).slice(1);
    var args = transaction.getArgs(txn).slice(1); // ignore path

    var caller = {session: req.session};

    callback.apply(caller, captures.concat(args).concat([function (isAllowed) {
      if (!isAllowed) return res.fail('Unauthorized', txn);
      return next();
    }]));
  }

  return guard;
}
