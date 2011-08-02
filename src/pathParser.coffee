# Interpret the path because it can be a regular
# path, or a path pattern using a special path grammar.

# TODO Improve this later once we finalize a path
#      grammar. Possibly use jison - http://zaach.github.com/jison/

module.exports =
  # Test to see if path name contains a segment that starts with an underscore.
  # Such a path is private to the current session and should not be stored
  # in persistent storage or synced with other clients.
  isPrivate: (name) -> /(^_)|(\._)/.test name
  
  regExp: (pattern) -> if pattern instanceof RegExp then pattern else
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
  
  fastLookup: (path, obj) ->
    for prop in path.split '.'
      return unless obj = obj[prop]
    return obj