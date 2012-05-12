{createAdapter} = require '../adapters'

exports.createJournal = (modeOptions) ->
  journal = createAdapter 'journal', modeOptions.journal || {type: 'Memory'}
