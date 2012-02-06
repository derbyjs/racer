
module.exports =

  diffArrays: (before, after) ->
    afterLen = after.length
    a = b = -1
    skipA = {}
    skipB = {}
    ops = []

    while a < afterLen

      while skipA[++a] then
      while skipB[++b] then
      itemAfter = after[a]
      itemBefore = before[b]

      if itemAfter == itemBefore
        addInsertOrRemove ops, after, insert, numInsert, remove, numRemove
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

      addInsertOrRemove ops, after, insert, numInsert, remove, numRemove
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

    # Turn move operations into moves forward or backward as appropriate.
    # Offset moves by inserts, removes, and moves going forward
    offset = 0
    toOffset = []
    moveDirections = []
    i = -1
    while op = ops[++i]
      method = op[0]

      switch method
        when 'insert'
          num = op.length - 2
          offset += num
          offsetMoves toOffset, moveDirections, op[1], -num
          continue

        when 'remove'
          index = op[1]
          op[1] += offset + offsetByMoves(toOffset, moveDirections, index)
          num = op[2]
          offset -= num
          offsetMoves toOffset, moveDirections, index, num
          continue

        when 'move'
          fromForward = op[1]
          toForward = op[2]
          numForward = op[3]
          fromForward += offset + offsetByMoves(toOffset, moveDirections, fromForward)

          fromBackward = op[4]
          toBackward = op[5]
          numBackward = op[6]
          fromBackward += offset + offsetByMoves(toOffset, moveDirections, fromBackward)

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
              toOffset.push ops[i] = ['move', fromForward, toForward, numForward]
              moveDirections.push dir
            else
              offset += numBackward
              toOffset.push ops[i] = ['move', fromBackward, toBackward, numBackward]
              moveDirections.push dir

          else
            offset += numBackward - numForward
            toOffset.push ops[i] = ['move', fromForward, toForward, numForward]
            toOffset.push op = ['move', fromBackward - numForward, toBackward, numBackward]
            ops.splice ++i, 0, op
            moveDirections.push 1, 0
    
    # Offset moves by other moves ahead of them
    i = toOffset.length
    while op = toOffset[--i]
      j = i
      from = op[1]
      to = op[2]
      if from < to
        start = from
        end = to
        offset = op[3]
      else
        start = to
        end = from
        offset = -op[3]

      while op = toOffset[--j]
        from = op[1]
        to = op[2]
        if from < to
          op[2] += offset if start <= to <= end
        else
          op[1] -= offset if start < from < end

    # Remove any moves that have the same from & to indicies
    i = ops.length
    while op = ops[--i]
      if op[0] is 'move' && op[1] == op[2]
        ops.splice i, 1

    return ops

offsetMoves = (toOffset, moveDirections, index, offset) ->
  for op, i in toOffset
    if moveDirections[i]
      op[2] += offset if index <= op[2]

offsetByMoves = (toOffset, moveDirections, index) ->
  offset = 0
  for op, i in toOffset
    num = op[3]
    if moveDirections[i]
      offset += num if op[2] < index
    else
      offset -= num if op[1] < index 
  return offset

moveLookAhead = (before, after, skipA, skipB, afterLen, from, to, otherItem) ->
  num = 1
  b = from
  a = to
  while (item = before[++b]) == after[++a] && a < afterLen
    return -1 if item == otherItem
    num++

  end = from + num
  while from < end
    skipB[from++] = true
    skipA[to++] = true
  return num

addInsertOrRemove = (ops, after, insert, numInsert, remove, numRemove) ->
  ops.push ['insert', insert, after.slice(insert, insert + numInsert)...]  if insert?
  ops.push ['remove', remove, numRemove]  if remove?
  return
