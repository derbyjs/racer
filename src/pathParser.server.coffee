pathParser = require './pathParser'

pathParser.splitPattern = (path) ->
  if ~(i = path.search /[\*\(]/)
    root = path.substr 0, i - 1  # Subtract one to remove the trailing '.'
    remainder = path.substr i
  else
    root = path
    remainder = ''
  [root, remainder]

pathParser.isGlob = (path) -> ~path.indexOf('*')

pathParser.glob = (pattern) ->
  # Convert subscribe pattern into a Redis psubscribe glob format equivalent
  # or a glob that is a superset of the pattern
  # Replace ** and (x|y) style patterns with *
  pattern.replace /(?:\*\*)|(?:\([^\)]*\))/g, '*'

module.exports = pathParser
