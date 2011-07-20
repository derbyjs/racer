# Interpret the path because it can be a regular
# path, or a path pattern using a special path grammar.
module.exports =
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
  # @return {Array} [paths, patterns, exceptions]
  forSubscribe: (path) ->
    # TODO Improve this later once we finalize a path
    #      grammar. Possibly use jison - http://zaach.github.com/jison/
    lastChar = path.charAt path.length-1
    if lastChar == '*'
      return [[], [path], []]
    return [[path], [], []]

  # Returns a normalized path for use with an adapter
  forPopulate: (path) ->
    # TODO Improve this later once we finalize a path
    #      grammar. Possibly use jison - http://zaach.github.com/jison/
    lastChar = path.charAt path.length-1
    if lastChar == '*'
      # Remove the .*
      return path.substring(0, path.length-2)
    return path
