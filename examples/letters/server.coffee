{app, store} = require './index'
racer = require 'racer'

# Clear any existing data, then initialize
store.flush (err) ->
  racer.sockets.on 'connection', (socket) ->
    socket.on 'join', (room) ->
      playersPath = "rooms.#{room}.players"
      store.incr playersPath
      socket.on 'disconnect', -> store.incr playersPath, -1
  app.listen 3000
  console.log "Go to http://localhost:3000/lobby"
  console.log "Go to http://localhost:3000/powder-room"
