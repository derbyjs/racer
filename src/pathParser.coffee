# Interpret the path because it can be a regular
# path, or a path pattern using a special path grammar.

# TODO Improve this later once we finalize a path
#      grammar. Possibly use jison - http://zaach.github.com/jison/

module.exports =
  # Test to see if path name contains a segment that starts with an underscore.
  # Such a path is private to the current session and should not be stored
  # in persistent storage or synced with other clients.
  isPrivate: (name) -> /(?:^_)|(?:\._)/.test name

  regExp: (pattern) -> if pattern instanceof RegExp then pattern else
    new RegExp '^' + pattern.replace(/[.*]/g, (match, index) ->
      # Escape periods
      return if match is '.' then '\\.'
      # An asterisk matches any single path segment in the middle
      # and any path or paths at the end
      else if pattern.length - index is 1 then '(.+)' else '([^.]+)'
    ) + '$'

  fastLookup: (path, obj) ->
    for prop in path.split '.'
      return unless obj = obj[prop]
    return obj

  split: (path) ->
    if ~(i = path.search /[*(]/)
      root = path.substr 0, i - 1  # Subtract one to remove the trailing '.'
      remainder = path.substr i
    else
      root = path
      remainder = ''
    [root, remainder]

  expand: (path) ->
    # Ignore all whitespace and line break characters
    path = path.replace /\s\n/g, ''
    stack = []
    while path
      unless match = /^([^,()]*)([,()])(.*)/.exec path
        stack.push path
        break
      pre = match[1]
      token = match[2]
      path = match[3]

      stack.push pre  if pre
      if token is '('
        parent = stack
        parent.push stack = []
        stack.parent = parent
      else if token is ')'
        stack = stack.parent
    
    return unroll stack, ['']

unroll = (stack, paths) ->
  out = []
  for item in stack
    if typeof item is 'string'
      for path in paths
        out.push path + item
    else unroll stack, out
  return out
