doc = document
board = doc.getElementById 'board'
dragData = null

board.addEventListener 'dragstart', (e) ->
  dt = e.dataTransfer
  dt.effectAllowed = 'move'
  dt.dropEffect = 'move'
  dt.setData 'text', 0
  
  # Store the dragged letter and the offset of the click position
  # from the letter's position
  dragData =
    target: e.target
    offsetX: e.offsetX
    offsetY: e.offsetY

board.addEventListener 'dragover', (e) ->
  e.preventDefault()
  
board.addEventListener 'drop', (e) ->
  e.preventDefault()
  
  # Calculate the new position for the letter
  x = e.offsetX - dragData.offsetX
  y = e.offsetY - dragData.offsetY
  console.log e.target
  if (target = e.target) != board
    target = target.parentNode if target.parentNode != board
    # If dropped on another letter, add the offset of that letter
    x += target.offsetLeft
    y += target.offsetTop
  
  # Move the letter to its new position
  dragTarget = dragData.target
  dragTarget.style.left = x + 'px'
  dragTarget.style.top = y + 'px'
  
  # Put the most recently dragged letter on top
  dragTarget.parentNode.appendChild dragTarget