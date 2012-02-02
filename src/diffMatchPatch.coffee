
module.exports =

  diffArrays: (before, after, onInsert, onRemove, onMove) ->
    afterLen = after.length
    a = b = -1
    offset = 0
    skipA = {}
    skipB = {}
    offsetAt = {}

    while a < afterLen

      while skipA[++a] then
      while skipB[++b] then
      itemAfter = after[a]
      itemBefore = before[b]

      for i of offsetAt
        if i <= a
          offset += offsetAt[i]
          delete offsetAt[i]
      
      if itemBefore == itemAfter
        offset = emit onInsert, onRemove, onMove, insert, remove, move, before, after, a, b, numInsert, numRemove, fromForward, toForward, numForward, fromBackward, toBackward, numBackward, offset, offsetAt
        insert = remove = move = null
        continue

      if a < afterLen && (indexAfter = before.indexOf itemAfter) == -1
        unless insert?
          insert = a
          numInsert = 0
        numInsert++
        b--
        continue

      if (indexBefore = after.indexOf itemBefore) == -1
        unless remove?
          remove = a
          numRemove = 0
        numRemove++
        a--
        continue

      offset = emit onInsert, onRemove, onMove, insert, remove, move, before, after, a, b, numInsert, numRemove, fromForward, toForward, numForward, fromBackward, toBackward, numBackward, offset, offsetAt
      insert = remove = null
      move = true

      fromForward = b + offset
      toForward = indexBefore
      numForward = lookAhead before, after, afterLen, skipA, skipB, b, indexBefore

      fromBackward = indexAfter + offset
      toBackward = a
      numBackward = lookAhead before, after, afterLen, skipA, skipB, indexAfter, a

      for i of offsetAt
        fromBackward += offsetAt[i]  if i < indexAfter

    return

emit = (onInsert, onRemove, onMove, insert, remove, move, before, after, a, b, numInsert, numRemove, fromForward, toForward, numForward, fromBackward, toBackward, numBackward, offset, offsetAt) ->
  if move?
    if a < toForward
      onMove fromForward, toForward, numForward
      offset -= numForward
      offsetAt[toForward] = (offsetAt[toForward] || 0) + numForward
      fromBackward -= numForward
      if fromBackward != toBackward
        onMove fromBackward, toBackward, numBackward
        offset += numBackward
        offsetAt[fromBackward] = (offsetAt[fromBackward] || 0) - numBackward
    else if a < fromBackward
      onMove fromBackward, toBackward, numBackward
      offset += numBackward
      offsetAt[fromBackward] = (offsetAt[fromBackward] || 0) - numBackward
    else
      # The move was a simple swap, so only emit one move.
      # Choose the one that moves fewer items
      if numForward <= numBackward
        onMove fromForward, toForward, numForward
      else
        onMove fromBackward, toBackward, numBackward
  if insert?
    onInsert insert, after.slice(insert, insert + numInsert)
    offset += numInsert
  if remove?
    onRemove remove, numRemove
    offset -= numRemove
  return offset

lookAhead = (before, after, afterLen, skipA, skipB, from, to) ->
  num = 1
  skipA[to] = true
  skipB[from] = true
  while to < afterLen && before[++from] == after[++to]
    num++
    skipA[to] = true
    skipB[from] = true
  return num
