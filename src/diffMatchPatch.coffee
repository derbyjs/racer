
module.exports =

  diffArrays: (before, after) ->
    afterLen = after.length
    a = b = -1
    skipA = {}
    skipB = {}
    ops = []
    inserts = []
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

      # console.log a, b, skipA, skipB

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

      ops.push ['move', b, indexBefore, numForward, indexAfter, a, numBackward]


    # Removes are all emitted first. Offset the indices of removes after other removes
    # and the indicies of moves by removes
    offset = 0
    for op in removes
      index = op[1] += offset
      num = op[2]
      offset -= num
      for op in ops
        op[1] -= num  if index < op[1]
        op[4] -= num  if index < op[4]

    # Inserts are all emitted last. Offset the indices of moves by inserts 
    for op in inserts
      num = op.length - 2
      index = op[1]
      for op in ops
        op[2] -= num  if index < op[2]
        op[5] -= num  if index < op[5]

    moves = []
    offset = 0
    i = -1
    while op = ops[++i]

      fromForward = op[1]
      toForward = op[2]
      numForward = op[3]
      fromForwardOffset = fromForward + forwardOffset(moves, fromForward, offset)

      fromBackward = op[4]
      toBackward = op[5]
      numBackward = op[6]
      fromBackwardOffset = fromBackward + forwardOffset(moves, fromBackward, offset)

      if numForward == -1
        singleMove = true
        dir = 0
      else if numBackward == -1
        singleMove = true
        dir = 1
      else
        sameForward = toBackward == fromBackwardOffset - numForward
        sameBackward = toForward == fromForwardOffset + numBackward

        singleMove = sameForward || sameBackward
        dir = if sameForward && sameBackward
            numForward <= numBackward
          else
            sameForward

      if singleMove
        if dir
          offset -= numForward
          ops[i] = op = ['move', fromForwardOffset, toForward, numForward]
          moves.push {dir: 1, op}
        else
          offset += numBackward
          ops[i] = op = ['move', fromBackwardOffset, toBackward, numBackward]
          moves.push {dir: 0, op}

      else
        offset += numBackward - numForward
        ops[i] = op = ['move', fromForwardOffset, toForward, numForward]
        moves.push {dir: 1, op}

        fromBackwardOffset -= numForward  if toForward >= fromBackwardOffset
        op = ['move', fromBackwardOffset, toBackward, numBackward]
        ops.splice ++i, 0, op
        moves.push {dir: 0, op}

    # console.log moves

    # Offset moves by other moves going backwards
    i = moves.length
    while move = moves[--i]
      op = move.op
      if move.dir
        start = op[1]
        end = op[2]
        offset = op[3]
      else
        start = op[2]
        end = op[1]
        offset = -op[3]

      j = i
      while move = moves[--j]
        op = move.op
        if move.dir
          op[2] += offset if start <= op[2] <= end
        else
          op[1] -= offset if start < op[1] < end

    # Remove any no-op moves
    # i = ops.length
    # while op = ops[--i]
    #   if op[0] is 'move' && op[1] == op[2]
    #     ops.splice i, 1

    return removes.concat ops, inserts

forwardOffset = (moves, index, offset) ->
  for move in moves
    op = move.op
    if move.dir
      offset += op[3] if op[2] < index
    else
      offset -= op[3] if op[1] < index
  return offset

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
