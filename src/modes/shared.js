var createAdapter = require('../adapters').createAdapter;

exports.createJournal = function (modeOptions) {
  return createAdapter('journal', modeOptions.journal || {type: 'Memory'});
};

exports.createStartIdVerifier = function (getStartId) {
  return function (req, res, next) {
    if (req.ignoreStartId) return next();
    // Could be the case if originating from Store and no Model has been
    // initialized.
    // TODO Re-visit this. This could be insecure if req.startId is never assigned
    var clientStartId = req.startId;
    getStartId( function (err, startId) {
      if (err) return res.fail(err);

      if (clientStartId && clientStartId !== startId) {
        return res.fail('clientStartId != startId (' + clientStartId + ' != ' + startId + ')');
      }
      return next();
    });
  };
};
