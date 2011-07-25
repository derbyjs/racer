pathParser = require './pathParser'

  # Return 3 sets:
  # 1. A set of paths to subscribe to
  # 2. A set of patterns to subscribe to
  # 3. A set of paths to ignore upon a pmessage
  # The first 2 sets form a minimum sized set that spans
  # all potential paths representative by path.
  #
  # The 2nd set may send messages to the subscriber that it
  # should ignore. The 3rd set returned is therefore a set of
  # exceptions used to filter incoming pmessages.
  #
  # @param {String} path
  # @return {Object} {paths, patterns, exceptions}
pathParser.forSubscribe = (path) ->
  if Array.isArray path
    paths = path
    triplets = paths.map (path) =>
      res = {_paths, _patterns, _exceptions} = @forSubscribe path

    paths = []
    patterns = []
    exceptions = []
    for triplet in triplets
      paths = paths.concat triplet.paths
      patterns = patterns.concat triplet.patterns
      exceptions = exceptions.concat triplet.exceptions
    return {
      paths: paths
      patterns: patterns
      exceptions: exceptions
    }
  else
    lastChar = path.charAt path.length-1
    if lastChar == '*'
      return {
        paths: []
        patterns: [path]
        exceptions: []
      }
    return {
      paths: [path]
      patterns: []
      exceptions: []
    }

pathParser.conflictsWithPattern = (path, pattern) ->
  base = pattern.replace /\.\*$/, ''
  base == path.substr(0, base.length)

pathParser.isPattern = (path) ->
  /\.\*$/.test path

module.exports = pathParser
