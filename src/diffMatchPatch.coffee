
module.exports =

  diffArrays: (before, after, onInsert, onRemove, onMove) ->
    afterLen = after.length
    i = j = -1
    offset = 0
    skip = {}

    while i < afterLen
      item = after[++i]
      while skip[++j] then
      oldItem = before[j]

      if oldItem == item
        if move?
          onMove move, to, numMove
          move = null
        if insert?
          onInsert insert, after.slice(insert, i)
          insert = null
        if remove?
          onRemove removeIndex, numRemove
          remove = null
        continue

      if i < afterLen && (index = before.indexOf(item)) == -1
        unless insert?
          insert = i
        offset++
        j--
        continue

      if after.indexOf(oldItem) == -1
        unless remove?
          remove = j
          removeIndex = i
          numRemove = 0
        numRemove++
        offset--
        i--
        continue

      else
        if move? && (move != index + offset - numMove)
          onMove move, to, numMove
          move = null
          if to <= j + offset
            offset++
        if insert?
          onInsert insert, after.slice(insert, i)
          insert = null
        if remove?
          onRemove removeIndex, numRemove
          remove = null

        unless move?
          move = index + offset
          to = j + offset
          numMove = 0
        numMove++
        j--
        skip[index] = true
