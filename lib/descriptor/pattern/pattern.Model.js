var basePattern = require('./base')
  , mergeAll = require('../../util').mergeAll
  , splitPath= require('../../path').split
  ;

/**
 * Takes care of all the book-keeping in the Model for fetching and subscribing
 * to a path pattern.
 */
module.exports = {
  type: 'Model'
, events: {
    init: function (model) {
      // `_patternSubs` remembers path subscriptions.
      // This memory is useful when the client may have been disconnected from
      // the server for quite some time and needs to re-send its subscriptions
      // upon a re-connection in order for the server (1) to figure out what
      // data the client needs to re-sync its snapshot and (2) to re-subscribe
      // to the data on behalf of the client. The paths and queries get cached
      // in Model#subscribe
      model._patternSubs = {}; // pattern: Boolean
    }

  , bundle: function (model, addToBundle) {
      addToBundle('_loadPatternSubs', model._patternSubs);
    }
  }

, decorate: function (Model) {
    var modelPattern = mergeAll({
      scopedResult: function (model, pattern) {
        var pathToGlob = splitPath(pattern)[0];
        return model.at(pathToGlob);
      }
    , registerFetch: function (model, pattern) {
        // TODO Needed or remove this?
      }
    , registerSubscribe: function (model, pattern) {
        var subs = model._patternSubs;
        if (pattern in subs) return;
        return subs[pattern] = true;
      }
    , unregisterSubscribe: function (model, pattern) {
        var patternSubs = model._patternSubs;
        if (! (pattern in patternSubs)) return;
        delete patternSubs[pattern];
      }
    , subs: function (model) {
        return Object.keys(model._patternSubs);
      }
    // TODO Need something for snapshot?
    }, basePattern);

    Model.dataDescriptor(modelPattern);
  }

, proto: {
    _loadPatternSubs: function (patternSubs) {
      this._patternSubs = patternSubs;
    }
  }
};
