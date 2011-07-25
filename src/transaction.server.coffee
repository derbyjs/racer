transaction = require './transaction'

# Ported from Python implementation of fnmatch.py translate function
# http://svn.python.org/view/python/branches/release27-maint/Lib/fnmatch.py?view=markup
transaction.globToRegExp = (pattern) ->
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
  new RegExp res + '$'

transaction.conflict = (txnA, txnB) ->
  # txnA is a new transaction, and txnB is an already committed transaction
  
  # There is no conflict if the paths don't conflict
  return false if !@pathConflict(txnA[3], txnB[3])
  
  # There is no conflict if the transactions are from the same model client
  # and the new transaction was from a later client version.
  # However, this is not true for stores, whose IDs start with a '$'
  if txnA[1].charAt(0) != '$'
    idA = txnA[1].split '.'
    idB = txnB[1].split '.'
    clientIdA = idA[0]
    clientIdB = idB[0]
    if clientIdA == clientIdB
      clientVerA = idA[1] - 0
      clientVerB = idB[1] - 0
      return false if clientVerA > clientVerB
  
  # Ignore transactions with the same ID as an already committed transaction
  return 'duplicate' if txnA[1] == txnB[1]
  
  # There is no conflict if the new transaction has exactly the same method,
  # path, and arguments as the committed transaction
  lenA = txnA.length
  i = 2
  while i < lenA
    return 'conflict' if txnA[i] != txnB[i]
    i++
  return 'conflict' if lenA != txnB.length
  return false

transaction.pathConflict = (pathA, pathB) ->
  # Paths conflict if either is a sub-path of the other
  return true if pathA == pathB
  pathALen = pathA.length
  pathBLen = pathB.length
  return false if pathALen == pathBLen
  if pathALen > pathBLen
    return pathA.charAt(pathBLen) == '.' && pathA.substring(0, pathBLen) == pathB
  return pathB.charAt(pathALen) == '.' && pathB.substring(0, pathALen) == pathA

transaction.journalConflict = (txn, txns) ->
  i = txns.length
  while i--
    return conflict if conflict = @conflict txn, JSON.parse(txns[i])
  return false