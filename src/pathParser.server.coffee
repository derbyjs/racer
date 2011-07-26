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
  globRe = /\*/
  _paths = []
  _patterns = []

  if Array.isArray path
    paths = path
    for path in paths
      if globRe.test path
        _patterns.push path
      else
        _paths.push path
  else
    if globRe.test path
      _patterns.push path
    else
      _paths.push path
  return [_paths, _patterns]

pathParser.conflictsWithPattern = (path, pattern) ->
  base = pattern.replace /\.\*$/, ''
  base == path.substr(0, base.length)

pathParser.matchesAnyPattern = (path, patterns) ->
  for pattern in patterns
    return true if pattern.test path
  return false

pathParser.isPattern = (path) ->
  /\.\*$/.test path

# Ported from Python implementation of fnmatch.py translate function
# http://svn.python.org/view/python/branches/release27-maint/Lib/fnmatch.py?view=markup
pathParser.globToRegExp = (pattern) ->
  # Translate a shell PATTERN to a regular expression.
  # There is no way to quote meta-characters.
  i = 0
  n = pattern.length
  res = ''
  while i < n
    c = pattern.charAt(i)
    i++
    if c == '*'
      res += '.*'
    else if c == '?'
      res += '.'
    else if c == '['
      j = i
      if j < n and pattern.charAt(j) == '!'
        j++
      if j < n and pattern.charAt(j) == ']'
        j++
      while j < n and pattern.charAt(j) != ']'
        j++
      if j >= n
        res = res + '\\['
      else
        stuff = pattern.substring(i, j).replace('\\', '\\\\')
        i = j + 1
        if stuff.charAt(0) == '!'
          stuff = '^' + stuff.substr(1)
        else if stuff.charAt(0) == '^'
          stuff = '\\' + stuff
        res = "#{res}[#{stuff}]"
    else
      # Regular expression escaping from: http://xregexp.com/xregexp.js
      res = res + c.replace(/[-[\]{}()*+?.,\\^$|#\s]/, '\\$&')
  new RegExp '^' + res + '$'


module.exports = pathParser
