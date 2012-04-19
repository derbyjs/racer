{deepCopy} = require '../../lib/util'

modesWithJournal =
  lww: false
  stm: true

exports.augmentStoreOpts = (storeOpts, mode) ->
  opts = deepCopy storeOpts
  opts.mode ||= {}
  opts.mode.type = mode
  if modesWithJournal[mode] == true
    opts.mode.journal ||= type: 'Memory'
  else if modesWithJournal[mode] == false
    delete opts.mode.journal
  else
    throw new Error 'Specify if this mode needs a journal'
  return opts
