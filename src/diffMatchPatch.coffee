
module.exports =

  diffArrays: (before, after, onInsert, onRemove, onMove) ->
    afterLen = after.length
    a = b = -1
    offset = 0
    skipA = {}
    skipB = {}
    offsetAt = {}
    pendingMoves = []

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
        offset = emit onInsert, onRemove, onMove, insert, remove, move, before, after, a, b, numInsert, numRemove, fromForward, toForward, numForward, fromBackward, toBackward, numBackward, offset, offsetAt, pendingMoves
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

      offset = emit onInsert, onRemove, onMove, insert, remove, move, before, after, a, b, numInsert, numRemove, fromForward, toForward, numForward, fromBackward, toBackward, numBackward, offset, offsetAt, pendingMoves
      insert = remove = null
      move = true

      fromForward = b + offset
      toForward = indexBefore
      numForward = lookAhead before, after, afterLen, skipA, skipB, b, indexBefore

      fromBackward = indexAfter + offset
      toBackward = a
      numBackward = lookAhead before, after, afterLen, skipA, skipB, indexAfter, a

      console.log offsetAt, pendingMoves
      for i of offsetAt
        fromBackward += offsetAt[i]  if i <= fromBackward

    return

emit = (onInsert, onRemove, onMove, insert, remove, move, before, after, a, b, numInsert, numRemove, fromForward, toForward, numForward, fromBackward, toBackward, numBackward, offset, offsetAt, pendingMoves) ->
  if move?

    console.log fromForward, toForward, fromBackward, toBackward

    for pending in pendingMoves
      [from, to, num] = pending
      fromForward -= num  if fromForward <= to
      toBackward += num  if from < toBackward

    console.log fromForward, toForward, fromBackward, toBackward

    gapBackward = toBackward != fromBackward - numForward
    gapForward = fromForward != toForward - numBackward

    if gapBackward
      onMove fromBackward, toBackward, numBackward
      offset += numBackward
      offsetAt[fromBackward] = (offsetAt[fromBackward] || 0) - numBackward

      for pending in pendingMoves
        pending[0] += numBackward  if toBackward <= pending[0]

      fromForward += numBackward
      if fromForward != toForward
        pendingMoves.push [fromForward, toForward, numForward]

    else if gapForward
      pendingMoves.push [fromForward, toForward, numForward]

    else
      # The move was a simple swap, so only emit one move.
      # Choose the one that moves fewer items
      if numForward <= numBackward
        pendingMoves.push [fromForward, toForward, numForward]
      else
        onMove fromBackward, toBackward, numBackward

  if insert?
    pendingOffset = 0
    for pending in pendingMoves
      pendingOffset += pending[2]  if pending[0] < insert

    onInsert insert + pendingOffset, after.slice(insert, insert + numInsert)
    offset += numInsert

  if remove?
    pendingOffset = 0
    for pending in pendingMoves
      pendingOffset += pending[2]  if pending[0] < remove

    onRemove remove + pendingOffset, numRemove
    offset -= numRemove

  while pending = pendingMoves[0]
    to = pending[1]
    break unless to <= a
    onMove pending[0], to, pending[2]
    pendingMoves.shift()

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
