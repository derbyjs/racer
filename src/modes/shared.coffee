{createAdapter} = require '../adapters'

exports.createJournal = (modeOptions) ->
  journal = createAdapter 'journal', modeOptions.journal || {type: 'Memory'}

exports.createStartIdVerifier = (getStartId) ->
  return (req, res, next) ->
    return next() if req.ignoreStartId
    # Could be the case if originating from Store and no Model has been
    # intialized
    # TODO Re-visit this. This could be insecure if req.startId is never assigned
    clientStartId = req.startId
    getStartId (err, startId) ->
      return res.fail err if err
      if clientStartId && clientStartId != startId
        return res.fail "clientStartId != startId (#{clientStartId} != #{startId})"
      return next()
