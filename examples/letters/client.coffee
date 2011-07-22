rally = require 'rally'

window.onload = ->
  model = rally.model
  info = document.getElementById 'info'
  board = document.getElementById 'board'
  dragData = null
  
  updateInfo = ->
    players = model.get '_room.players'
    info.innerHTML =
      if model.socket.socket.connected
        players + ' Player' + if players > 1 then 's' else ''
      else
        'Offline'
  model.on 'set', '_room.players', updateInfo
  model.socket.on 'connect', -> model.socket.emit 'join', model.get '_roomName'
  model.socket.on 'disconnect', updateInfo
  
  html = ''
  if `/*@cc_on!@*/0`
    # If IE, use a link element, since only images and links can be dragged
    open = '<a href=# onclick="return false"'
    close = '</a>'
  else
    open = '<span'
    close = '</span>'
  for id, letter of model.get "_room.letters"
    html += """#{open} draggable=true class="#{letter.color} letter" id=#{id}
    style=left:#{letter.left}px;top:#{letter.top}px>#{letter.value}#{close}"""
  board.innerHTML = html
  
  # Disable selection in IE
  addListener board, 'selectstart', -> false

  addListener board, 'dragstart', (e) ->
    e.dataTransfer.effectAllowed = 'move'
    # At least one data item must be set to enable dragging
    e.dataTransfer.setData 'Text', 'x'

    # Store the dragged letter and the offset of the click position
    target = e.target || e.srcElement
    dragData =
      target: target
      startLeft: e.clientX - target.offsetLeft
      startTop: e.clientY - target.offsetTop

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
    
    # Update the model to reflect the drop position
    dragTarget = dragData.target
    letterPath = '_room.letters.' + dragTarget.id
    model.set letterPath + '.left', e.clientX - dragData.startLeft
    model.set letterPath + '.top', e.clientY - dragData.startTop
    
    # Put the most recently dragged letter on top
    dragTarget.parentNode.appendChild dragTarget
  
  # Update the letter's position when the model changes
  # Path wildcards are passed to the handler function as arguments in order.
  # The function arguments are: (wildcards..., value)
  model.on 'set', '_room.letters.*.(left|top)', (id, prop, value) ->
    el = document.getElementById id
    el.style[prop] = value + 'px'

if document.addEventListener
  addListener = (el, type, listener) ->
    el.addEventListener type, listener, false
else
  addListener = (el, type, listener) ->
    el.attachEvent 'on' + type, (e) ->
      listener e || event
