
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

      addInsertOrRemove ops, after, insert, numInsert, remove, numRemove
      insert = remove = null

      numForward = moveLookAhead before, after, afterLen, skipA, skipB, b, indexBefore
      numBackward = moveLookAhead before, after, afterLen, skipA, skipB, indexAfter, a
      ops.push ['move', b, indexBefore, numForward, indexAfter, a, numBackward]

    offset = 0
    toOffset = []
    i = -1
    while op = ops[++i]
      method = op[0]

      switch method
        when 'insert'
          num = op.length - 2
          offset += num
          offsetMoves toOffset, op[1], -num
          continue

        when 'remove'
          num = op[2]
          offset -= num
          offsetMoves toOffset, op[1], num
          continue

        when 'move'
          fromForward = op[1]
          toForward = op[2]
          numForward = op[3]
          fromBackward = op[4]
          toBackward = op[5]
          numBackward = op[6]

          fromForward += offset + offsetByMoves(toOffset, fromForward)
          fromBackward += offset + offsetByMoves(toOffset, fromBackward)

          sameForward = toBackward == fromBackward - numForward
          sameBackward = toForward == fromForward + numBackward

          if sameForward && sameBackward
            toOffset.push ops[i] = if numForward <= numBackward
                offset -= numForward
                offsetMovesByMove toOffset, fromForward, toForward, numForward
                ['move', fromForward, toForward, numForward]
              else
                offset += numBackward
                offsetMovesByMove toOffset, toBackward, fromBackward, -numBackward
                ['move', fromBackward, toBackward, numBackward]

          else if sameForward
            offset -= numForward
            offsetMovesByMove toOffset, fromForward, toForward, numForward
            toOffset.push ops[i] = ['move', fromForward, toForward, numForward]

          else if sameBackward
            offset += numBackward
            offsetMovesByMove toOffset, toBackward, fromBackward, -numBackward
            toOffset.push ops[i] = ['move', fromBackward, toBackward, numBackward]

          else
            offset += numBackward - numForward
            offsetMovesByMove toOffset, fromForward, toForward, numForward
            offsetMovesByMove toOffset, toBackward, fromBackward, -numBackward
            toOffset.push ops[i] = ['move', fromForward, toForward, numForward]
            toOffset.push op = ['move', fromBackward - numForward, toBackward, numBackward]
            ops.splice ++i, 0, op

    return ops

offsetMoves = (toOffset, index, offset) ->
  for op in toOffset
    from = op[1]
    to = op[2]
    if from < to
      op[2] += offset if index < to

offsetMovesByMove = (toOffset, start, end, offset) ->
  for op in toOffset
    from = op[1]
    to = op[2]
    if from < to
      # TODO: Test the bounds of this. Not sure if should be < or <=
      op[2] += offset if start < to <= end
    else
      # TODO: Test the bounds of this. Not sure if should be < or <=
      op[1] -= offset if start <= from < end

offsetByMoves = (toOffset, index) ->
  offset = 0
  for op in toOffset
    from = op[1]
    to = op[2]
    num = op[3]
    if from < to
      offset += num if to < index
    else
      offset -= num if from < index 
  return offset

moveLookAhead = (before, after, afterLen, skipA, skipB, from, to) ->
  num = 1
  skipA[to] = true
  skipB[from] = true
  while to < afterLen && before[++from] == after[++to]
    num++
    skipA[to] = true
    skipB[from] = true
  return num

addInsertOrRemove = (ops, after, insert, numInsert, remove, numRemove) ->
  ops.push ['insert', insert, after.slice(insert, insert + numInsert)...]  if insert?
  ops.push ['remove', remove, numRemove]  if remove?
  return
