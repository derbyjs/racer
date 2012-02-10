
module.exports =

  diffArrays: (before, after) ->
    afterLen = after.length
    a = b = -1
    skipA = {}
    skipB = {}
    inserts = []
    moves = []
    directions = []
    removes = []

    while a < afterLen

      while skipA[++a]
        addInsertOrRemove inserts, removes, after, insert, numInsert, remove, numRemove
        insert = remove = null
      while skipB[++b]
        addInsertOrRemove inserts, removes, after, insert, numInsert, remove, numRemove
        insert = remove = null
      itemAfter = after[a]
      itemBefore = before[b]

      if itemAfter == itemBefore
        addInsertOrRemove inserts, removes, after, insert, numInsert, remove, numRemove
        insert = remove = null
        continue
      
      indexAfter = before.indexOf itemAfter, b
      while skipB[indexAfter]
        indexAfter = before.indexOf itemAfter, indexAfter + 1

      if a < afterLen && indexAfter == -1
        unless insert?
          insert = a
          numInsert = 0
        numInsert++
        b--
        continue

      indexBefore = after.indexOf itemBefore, a
      while skipA[indexBefore]
        indexBefore = after.indexOf itemBefore, indexBefore + 1

      if indexBefore == -1
        unless remove?
          remove = b
          numRemove = 0
        numRemove++
        a--
        continue

      addInsertOrRemove inserts, removes, after, insert, numInsert, remove, numRemove
      insert = remove = null

      numBackward = moveLookAhead before, after, skipA, skipB, afterLen, indexAfter, a, itemBefore
      if numBackward == -1
        a--
        # Make sure nothing matches otherItem 
        otherItem = NaN
      else
        otherItem = itemAfter

      numForward = moveLookAhead before, after, skipA, skipB, afterLen, b, indexBefore, otherItem
      if numForward == -1
        b--

      moves.push ['move', b, indexBefore, numForward, indexAfter, a, numBackward]

    # Removes are all emitted first. Offset the indices of removes after other removes
    # and the indicies of moves by removes
    offset = 0
    for op in removes
      index = op[1] += offset
      num = op[2]
      offset -= num
      for move in moves
        move[1] -= num  if index < move[1]
        move[4] -= num  if index < move[4]

    # Inserts are all emitted last. Offset the indices of moves by inserts
    i = inserts.length
    while op = inserts[--i]
      num = op.length - 2
      index = op[1]
      for move in moves
        move[2] -= num  if index <= move[2]
        move[5] -= num  if index <= move[5]

    directions = {}
    offset = 0
    i = -1
    while op = moves[++i]
      _fromForward = fromForward = op[1]
      toForward = op[2]
      numForward = op[3]
      fromBackward = op[4]
      toBackward = op[5]
      numBackward = op[6]

      fromForward = fromOffset moves, directions, i, fromForward, offset
      fromBackward = fromOffset moves, directions, i, fromBackward, offset

      if numForward == -1
        singleMove = true
        dir = 0
      else if numBackward == -1
        singleMove = true
        dir = 1
      else
        sameForward = toBackward == fromBackward - numForward
        sameBackward = toForward == fromForward + numBackward

        singleMove = sameForward || sameBackward
        dir = if sameForward && sameBackward
            numForward <= numBackward
          else
            sameForward

      if singleMove
        if dir
          offset -= numForward
          moves[i] = ['move', fromForward, toForward, numForward]
          directions[i] = 1
          offsetMoves moves, directions, i, fromForward, toForward, numForward
        else
          offset += numBackward
          moves[i] = ['move', fromBackward, toBackward, numBackward]
          directions[i] = 0
          offsetMoves moves, directions, i, fromBackward, toBackward, numBackward

      else
        offset += numBackward
        moves[i] = ['move', fromBackward, toBackward, numBackward]
        directions[i] = 0
        offsetMoves moves, directions, i, fromBackward, toBackward, numBackward

        fromForward = fromOffset moves, directions, i, _fromForward, offset
        offset -= numForward
        moves.splice ++i, 0, ['move', fromForward, toForward, numForward]
        directions[i] = 1
        offsetMoves moves, directions, i, fromForward, toForward, numForward

    # Remove any no-op moves
    i = moves.length
    while move = moves[--i]
      moves.splice i, 1  if move[1] == move[2]

    return removes.concat moves, inserts

offsetMoves = (moves, directions, i, from, to, num) ->
  if directions[i]
    while op = moves[--i]
      if directions[i]
        op[2] += num if from <= op[2] <= to
    return

  while op = moves[--i]
    if directions[i]
      op[2] -= num if to <= op[2] <= from
    else
      if to < op[1] < from
        nextFrom = op[1] += num
        offsetMoves moves, directions, i, nextFrom, op[2], op[3]
  return

fromOffset = (moves, directions, i, from, offset) ->
  while move = moves[--i]
    if directions[i]
      offset += move[3] if move[2] < from
    else
      offset -= move[3] if move[1] < from
  return from + offset

moveLookAhead = (before, after, skipA, skipB, afterLen, from, to, otherItem) ->
  num = 1
  b = from
  a = to
  while (item = before[++b]) == after[++a] && a < afterLen
    return -1 if item == otherItem || skipB[b] || skipA[a]
    num++

  end = from + num
  while from < end
    skipB[from++] = true
    skipA[to++] = true
  return num

addInsertOrRemove = (inserts, removes, after, insert, numInsert, remove, numRemove) ->
  inserts.push ['insert', insert, after.slice(insert, insert + numInsert)...]  if insert?
  removes.push ['remove', remove, numRemove]  if remove?
  return
