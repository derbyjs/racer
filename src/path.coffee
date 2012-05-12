module.exports =
  # Test to see if path name contains a segment that starts with an underscore.
  # Such a path is private to the current session and should not be stored
  # in persistent storage or synced with other clients.
  isPrivate: (name) -> /(?:^_)|(?:\._)/.test name

  eventRegExp: (pattern) ->
   if pattern instanceof RegExp then pattern else
      new RegExp '^' + pattern.replace(/[,.*]/g, (match, index) ->
        # Escape periods
        if match is '.' then '\\.'
        # Commas can be used for or, as in path.(one,two)
        else if match is ',' then '|'
        # An asterisk matches any single path segment in the middle
        # and any path or paths at the end
        else if pattern.length - index is 1 then '(.+)' else '([^.]+)'
      ) + '$'

  regExp: (pattern) ->
    # Match anything if there is no pattern or the pattern is ''
    if !pattern then /^/ else
      new RegExp '^' + pattern.replace(/[.*]/g, (match, index) ->
        # Escape periods
        if match is '.' then '\\.'
        # An asterisk matches any single path segment in the middle
        else '[^.]+'
        # All subscriptions match the root and any path below the root
      ) + '(?:\\.|$)'

  # Create regular expression matching the path or any of its parents
  regExpPathOrParent: (path) ->
    p = ''
    source = (for segment, i in path.split '.'
      "(?:#{p += if i then '\\.' + segment else segment})"
    ).join '|'
    new RegExp '^(?:' + source + ')$'

  # Create regular expression matching any of the paths or
  # child paths of any of the paths
  regExpPathsOrChildren: (paths) ->
    source = ("(?:#{path}(?:\\..+)?)" for path in paths).join '|'
    new RegExp '^(?:' + source + ')$'

  lookup: (path, obj) ->
    if path.indexOf('.') == -1
      return obj[path]
    parts = path.split '.'
    for prop in parts
      return unless obj?
      obj = obj[prop]
    return obj

  assign: (obj, path, val) ->
    parts = path.split '.'
    lastIndex = parts.length-1
    for prop, i in parts
      if i == lastIndex
        obj[prop] = val
      else
        obj = obj[prop] ||= {}
    return

  split: (path) -> path.split /\.?[(*]\.?/

  expand: (path) ->
    # Remove whitespace and line break characters
    path = path.replace /[\s\n]/g, ''
    # Return right away if path doesn't contain any groups
    return [path]  unless ~path.indexOf('(')

    # Break up path groups into a list of equivalent paths that contain
    # only names and *
    stack = {paths: paths = [''], out: out = []}
    while path
      unless match = /^([^,()]*)([,()])(.*)/.exec path
        return (val + path for val in out)
      pre = match[1]
      token = match[2]
      path = match[3]

      if pre
        paths = (val + pre for val in paths)
        unless token is '('
          out = if lastClosed then paths else out.concat paths

      lastClosed = false
      if token is ','
        stack.out = stack.out.concat paths
        {paths} = stack
      else if token is '('
        stack = {parent: stack, paths, out: out = []}
      else if token is ')'
        lastClosed = true
        paths = out = stack.out.concat paths
        stack = stack.parent

    return out

  # Given a `path`, returns an array of length 3 with the namespace, id, and
  # relative path to the attribute.
  triplet: (path) ->
    parts = path.split '.'
    return [parts[0], parts[1], parts[2..].join('.')]

  subPathToDoc: (path) -> path.split('.')[0..1].join('.')
