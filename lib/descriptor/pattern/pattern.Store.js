var patternDescriptor = require('./base')
  , path = require('../../path')
  , splitPath = path.split
  , expandPath = path.expand
  , lookup = path.lookup
  , finishAfter = require('../../util/async').finishAfter
  ;

module.exports = {
  type: 'Store'

, events: {
    middleware: function (store, middleware, createMiddleware) {
      middleware.fetchPattern = createMiddleware();
      middleware.fetchPattern.add(function (req, res, next) {
        var paths = expandPath(req.target)
          , numPaths = paths.length
          , finish = finishAfter(numPaths, next)
          , dataTriplets = []
          , timesSendCalled = 0
          ;
        for (var i = numPaths; i--; ) {
          var _req = Object.create(req, {
            target: {value: paths[i]}
          });
          var _res = {
            fail: function (err) {
              res.fail(err);
            }
          , send: function (triplets) {
              dataTriplets = dataTriplets.concat(triplets);
              if (++timesSendCalled === numPaths) {
                res.send(dataTriplets, false);
              }
            }
          };
          middleware.fetchPath(_req, _res, finish);
        }
      });

      middleware.fetchPath = createMiddleware();
      middleware.fetchPath.add(function (req, res, next) {
        req.context.guardReadPath(req, res, next);
      });
      middleware.fetchPath.add(function (req, res, next) {
        var path = req.target
          , triplets = [];
        // TODO We need to pass back array of document ids to assign to
        //      queries.someid.resultIds
        store._fetchPathData(path, {
          each: function (path, datum, ver) {
            triplets.push([path, datum, ver]);
          }
        , done: function () {
            res.send(triplets);
            next();
          }
        });
      });

    }
  }

, decorate: function (Store) {
    Store.dataDescriptor(patternDescriptor);
  }

, proto: {
    /**
     * Fetches data associated with a path in our data tree.
     *
     * @param {String} path to data that we want to fetch
     * @param {Object} opts can have keys:
     *
     * - each: Function invoked for every matching document
     * - finish: Function invoked after the query results are fetched
     *   and after opts.each has been called on every matching document.
     * @api private
     */
    _fetchPathData: function (path, opts) {
      var eachDatumCb = opts.each
        , finish = opts.done
        , parts = splitPath(path)
        , root = parts[0]
        , remainder = parts[1];
      this.get(root, function (err, datum, ver) {
        if (err) return finish(err);
        if (typeof remainder === 'undefined') {
          eachDatumCb(path, datum, ver);
        } else {
          // The path looks like <root>.*.<remainder>
          // so set each property one level down
          patternMatchingDatum(root, remainder, datum, function (fullPath, datum) {
            eachDatumCb(fullPath, datum, ver);
          });
        }
        return finish(null);
      });
    }
  }
};

/**
 * @param {String} prefix is the part of the path up to ".*."
 * @param {String} remainder is the part of the path after ".*."
 * @param {Object} subDoc is the lookup value of the prefix
 * @param {Function} eachDatumCb is the callback for each datum matching the pattern
 * @api private
 */
function patternMatchingDatum (prefix, remainder, subDoc, eachDatumCb) {
  var parts          = splitPath(remainder)
    , appendToPrefix = parts[0]
    , remainder      = parts[1];
  for (var property in subDoc) {
    var value = subDoc[property];
    if (value.constructor !== Object && ! Array.isArray(value)) {
      // We can't lookup `appendToPrefix` on `value` in this case
      continue;
    }
    var newPrefix = prefix + '.' + property + '.' + appendToPrefix
      , newValue = lookup(appendToPrefix, value);
    if (typeof remainder === 'undefined') {
      eachDatumCb(newPrefix, newValue);
    } else {
      patternMatchingDatum(newPrefix, remainder, newValue, eachDatumCb);
    }
  }
}
