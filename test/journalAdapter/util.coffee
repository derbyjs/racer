{deepCopy} = require '../../lib/util'
JournalMemory = require '../../lib/adapters/journal-memory'

modesWithJournal =
  lww: false
  stm: true

exports.augmentStoreOpts = (storeOpts, mode) ->
  opts = deepCopy storeOpts
  opts.mode ||= {}
  opts.mode.type = mode
  if modesWithJournal[mode] == true
    opts.mode.journal ||= klass: JournalMemory
  else if modesWithJournal[mode] == false
    delete opts.mode.journal
  else
    throw new Error 'Specify if this mode needs a journal'
  return opts
