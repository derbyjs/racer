# Theses tests should be run against each adapter

module.exports = (run) ->

  run 'Store pubSub', run.allModes, require './integration.pubSub'
  run 'Store txns', run.allModes, require './integration.txns'
