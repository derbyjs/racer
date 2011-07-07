if document.addEventListener
  addListener = (el, type, listener) ->
    el.addEventListener type, listener, false
else
  addListener = (el, type, listener) ->
    el.attachEvent 'on' + type, (e) ->
      listener e || event

window.onload = ->
  board = document.getElementById 'board'
  dragData = null
  
  colors = ['red', 'yellow', 'blue', 'orange', 'green']
  letters = {}
  for row in [0..4]
    for col in [0..25]
      letters[row * 26 + col] =
        color: colors[row]
        value: String.fromCharCode(65 + col)
        x: col * 24 + 72
        y: row * 32 + 8
  html = ''
  if `/*@cc_on!@*/0`
    # If IE, wrap in a link element, since only images and links can be dragged
    open = '<a href=# onclick="return false"'
    close = '</a>'
  else
    open = '<span'
    close = '</span>'
  for id, letter of letters
    html += """#{open} draggable=true class="#{letter.color} letter" id=#{id}
    style=left:#{letter.x}px;top:#{letter.y}px>#{letter.value}#{close}"""
  board.innerHTML = html
  
  addListener board, 'selectstart', -> false

  addListener board, 'dragstart', (e) ->
    e.dataTransfer.effectAllowed = 'move'
    # At least one data item must be set
    e.dataTransfer.setData 'Text', 'x'

    # Store the dragged letter and the offset of the click position
    # from the letter's position
    target = e.target || e.srcElement
    dragData =
      target: target
      startX: e.clientX - target.offsetLeft
      startY: e.clientY - target.offsetTop

    target.style.opacity = 0.5

  addListener board, 'dragover', (e) ->
    # Enable dragging onto board
    e.preventDefault() if e.preventDefault
    e.dataTransfer.dropEffect = 'move'
    return false

  addListener board, 'dragend', (e) ->
    dragData.target.style.opacity = 1

  addListener board, 'drop', (e) ->
    # Prevent Firefox from redirecting
    e.preventDefault() if e.preventDefault

    # Move the letter to its new position
    dragTarget = dragData.target
    dragTarget.style.left = e.clientX - dragData.startX + 'px'
    dragTarget.style.top = e.clientY - dragData.startY + 'px'

    # Put the most recently dragged letter on top
    dragTarget.parentNode.appendChild dragTarget
