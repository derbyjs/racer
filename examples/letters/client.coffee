racer = require 'racer'

process.nextTick ->
  racer.init @init
  delete @init

racer.on 'ready', (model) ->

  info = document.getElementById 'info'
  board = document.getElementById 'board'
  roomsDiv = document.getElementById 'rooms'
  roomlist = document.getElementById 'roomlist'
  dragData = null
  letters = window.letters = {}

  updateInfo = ->
    if model.connected
      players = model.get '_room.players'
      html = players + ' Player' + if players > 1 then 's' else ''
      roomsVisibility = 'visible'
    else if model.canConnect
      html = 'Offline<span id=reconnect> &ndash; <a href=# onclick="return letters.connect()">Reconnect</a></span>'
      roomsVisibility = 'hidden'
    else
      html = 'Unable to reconnect &ndash; <a href=javascript:window.location.reload()>Reload</a>'
      roomsVisibility = 'hidden'
    if conflicts
      html += ''' &ndash; Another player made conflicting moves:&nbsp;
      <a href=# onclick="return letters.resolve()">Accept</a>&nbsp;
      <a href=# onclick="return letters.resolve(true)">Override</a>'''
    info.innerHTML = html
    roomsDiv.style.visibility = roomsVisibility

  letters.connect = ->
    reconnect = document.getElementById 'reconnect'
    reconnect.style.display = 'none'
    # Hide the reconnect link for a second so it looks like something is going on
    setTimeout (-> reconnect.style.display = 'inline'), 1000
    model.socket.socket.connect()
    return false

  updateRooms = ->
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
        """<li><a href="#{name}">#{text}</a>"""
    roomlist.innerHTML = html


  ## Update the DOM when the model changes ##

  model.socket.on 'connect', -> model.socket.emit 'join', model.get '_roomName'

  model.on 'connectionStatus', updateInfo

  model.on 'set', '_room.players', updateInfo

  model.on 'set', 'rooms.*.players', updateRooms

  # Path wildcards are passed to the handler function as arguments in order.
  # The function arguments are: (wildcards..., value)
  model.on 'set', '_room.letters.*.position', (id, position) ->
    el = document.getElementById id
    el.style.left = position.left + 'px'
    el.style.top = position.top + 'px'


  ## Make letters draggable using HTML5 drag drop ##

  addListener = if document.addEventListener
      (el, type, listener) ->
        el.addEventListener type, listener, false
    else
      (el, type, listener) ->
        el.attachEvent 'on' + type, (e) ->
          listener e || event

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
  letters.resolve = (override) ->
    for i, {clone, id, left, top} of conflicts
      board.removeChild clone
      moveLetter id, left, top if override
    conflicts = null
    updateInfo()
    return false

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
