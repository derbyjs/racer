# TODO Add set version of methods
module.exports =
  base: (txn) -> txn[0]
  id: (txn) -> txn[1]
  method: (txn) -> txn[2]
  args: (txn) -> txn.slice 3
  path: (txn) -> txn[3]
  clientId: (txn) -> @id(txn).split('.')[0]
  
  # Test to see if path name contains a segment that starts with an underscore.
  # Such a path is private to the current session and should not be stored
  # in persistent storage or synced with other clients.
  privatePath: (name) -> /(^_)|(\._)/.test name
  
  pathRegExp: (pattern) -> if pattern instanceof RegExp then pattern else
    new RegExp '^' + pattern.replace(/\.|\*{1,2}/g, (match, index) ->
      # Escape periods
      return '\\.' if match is '.'
      # A single asterisk matches any single path segment
      return '([^\\.]+)' if match is '*'
      # A double asterisk matches any path segment or segments
      return if match is '**'
        # Use greedy matching at the end of the path and
        # non-greedy matching otherwise
        if pattern.length - index is 2 then '(.+)' else '(.+?)'
    ) + '$'
