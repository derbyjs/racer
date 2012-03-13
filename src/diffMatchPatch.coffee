module.exports =

  diffArrays: (before, after) ->
    out = []
    current = before.slice()

    diffArrays before, after, removes = [], moves = [], inserts = []

    # TODO: Ideally, the diff algorithm should be able to fully compute
    # the diff in one pass. Unfortunately, it doesn't quite work that way
    # yet, but it seems to converge if run for multiple passes

    # Try applying the diff and then diff again until the arrays converge
    while removes.length || moves.length || inserts.length
      out = out.concat removes, moves, inserts

      for op in removes
        current.splice op[1], op[2]
      for op in moves
        items = current.splice op[1], op[3]
        current.splice op[2], 0, items...
      for op in inserts
        current.splice op[1], 0, op.slice(2)...

      diffArrays current, after, removes = [], moves = [], inserts = []

    return out

diffArrays = (before, after, removes, moves, inserts) ->

  afterLen = after.length
  a = b = -1
  skipA = {}
  skipB = {}

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

    fromBackward = indexAfter
    toBackward = a
    numBackward = moveLookAhead before, after, skipA, skipB, afterLen, fromBackward, toBackward, itemBefore

    fromForward = b
    toForward = indexBefore
    # If backward move look ahead failed, use NaN (which nothing will match)
    # in the forward look ahead 
    otherItem = if numBackward == -1 then NaN else itemAfter
    numForward = moveLookAhead before, after, skipA, skipB, afterLen, fromForward, toForward, otherItem

    dir = if numBackward == -1
        # If there was a problem with the backward move look ahead, move forward
        dir = true
      else if numForward == -1
        # If there was a problem with the forward move look ahead, move backward
        dir = false
      else
        # Otherwise, favor the move of fewer items
        numForward < numBackward

    if dir
      from = fromForward
      to = toForward
      num = numForward
      a--
    else
      from = fromBackward
      to = toBackward
      num = numBackward
      b--

    moves.push ['move', from, to, num]
    end = from + num
    while from < end
      skipB[from++] = true
      skipA[to++] = true

  # Removes are all emitted first. Offset the indices of removes after other removes
  # and the indicies of moves by removes
  offset = 0
  for op in removes
    index = op[1] += offset
    num = op[2]
    offset -= num
    for move in moves
      move[1] -= num  if index < move[1]

  # Inserts are all emitted last. Offset the indices of moves by inserts
  i = inserts.length
  while op = inserts[--i]
    num = op.length - 2
    index = op[1]
    for move in moves
      move[2] -= num  if index <= move[2]

  for op, i in moves
    from = op[1]
    to = op[2]
    num = op[3]

    j = i
    while move = moves[++j]
      moveFrom = move[1]
      continue if to < moveFrom && from < moveFrom
      move[1] = if from < moveFrom then moveFrom - num else moveFrom + num

  return

moveLookAhead = (before, after, skipA, skipB, afterLen, b, a, otherItem) ->
  num = 1
  return -1 if skipB[b] || skipA[a]
  while (item = before[++b]) == after[++a] && a < afterLen
    return num if item == otherItem || skipB[b] || skipA[a]
    num++
  return num

addInsertOrRemove = (inserts, removes, after, insert, numInsert, remove, numRemove) ->
  inserts.push ['insert', insert, after.slice(insert, insert + numInsert)...]  if insert?
  removes.push ['remove', remove, numRemove]  if remove?
  return
