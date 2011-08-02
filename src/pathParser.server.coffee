pathParser = require './pathParser'

pathParser.isGlob = (path) -> ~path.indexOf('*')

pathParser.glob = (pattern) ->
  # Convert subscribe pattern into a Redis psubscribe glob format equivalent
  # or a glob that is a superset of the pattern
  # Replace ** and (x|y) style patterns with *
  pattern.replace /(?:\*\*)|(?:\([^\)]*\))/g, '*'

module.exports = pathParser
