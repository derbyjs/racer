rally = require 'rally'
resolve = ->
connect = ->

rally.onload = ->
  model = rally.model
  info = document.getElementById 'info'
  board = document.getElementById 'board'
  roomsDiv = document.getElementById 'rooms'
  roomlist = document.getElementById 'roomlist'
  dragData = null
  
  updateInfo = ->
    players = model.get '_room.players'    
    if model.socket.socket.open
      html = players + ' Player' + if players > 1 then 's' else ''
      roomsDiv.style.visibility = 'visible'
    else
      html = 'Offline &ndash; <a href=# onclick=connect()>Reconnect</a>'
      roomsDiv.style.visibility = 'hidden'
    if conflicts
      html += ''' &ndash; Another player made conflicting moves:&nbsp;
      <a href=# onclick=resolve()>Accept</a>&nbsp;
      <a href=# onclick=resolve(true)>Override</a>'''
    info.innerHTML = html
  model.on 'set', '_room.players', updateInfo
  model.socket.on 'connect', -> model.socket.emit 'join', model.get '_roomName'
  model.socket.on 'close', updateInfo
  
  connect = -> model.socket.socket.connect()
  
  model.on 'set', 'rooms.*.players', ->
    rooms = []
    for name, room of model.get 'rooms'
      rooms.push {name, players} if players = room.players
    rooms.sort (a, b) -> return b.players - a.players
    html = ''
    currentName = model.get '_roomName'
    for room in rooms
      name = room.name
      display = (name.charAt(0).toUpperCase() + name.substr(1)).replace /-/g, ' '
      text = "#{display} (#{room.players})"
      html += if name == currentName then """<li><b>#{text}</b>""" else
        """<li><a href="/#{name}">#{text}</a>"""
    roomlist.innerHTML = html
  
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
    style=left:#{letter.position.left}px;top:#{letter.position.top}px>#{letter.value}#{close}"""
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
    moveLetter dragData.target.id,
      e.clientX - dragData.startLeft,
      e.clientY - dragData.startTop
  
  conflicts = null
  resolve = (override) ->
    for i, conflict of conflicts
      board.removeChild conflict.clone
      moveLetter conflict.id, conflict.left, conflict.top if override
    conflicts = null
    updateInfo()
  
  moveLetter = (id, left, top) ->
    model.set "_room.letters.#{id}.position", {left, top}, (err) ->
      return unless err is 'conflict'
      # Only show the last conflicting move for each letter
      cloneId = id + 'clone'
      if existing = document.getElementById cloneId
        board.removeChild existing
      # Show a ghost of conflicting move that was not able to be committed
      clone = document.getElementById(id).cloneNode true
      clone.id = cloneId
      clone.style.left = left + 'px'
      clone.style.top = top + 'px'
      clone.style.opacity = 0.5
      clone.draggable = false
      board.appendChild clone
      conflicts ||= {}
      conflicts[cloneId] = {clone, id, left, top}
      updateInfo()
  
  # Update the letter's position when the model changes
  # Path wildcards are passed to the handler function as arguments in order.
  # The function arguments are: (wildcards..., value)
  model.on 'set', '_room.letters.*.position', (id, position) ->
    el = document.getElementById id
    el.style.left = position.left + 'px'
    el.style.top = position.top + 'px'

if document.addEventListener
  addListener = (el, type, listener) ->
    el.addEventListener type, listener, false
else
  addListener = (el, type, listener) ->
    el.attachEvent 'on' + type, (e) ->
      listener e || event
