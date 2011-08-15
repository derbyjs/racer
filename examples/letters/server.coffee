racer = require 'racer'
express = require 'express'
fs = require 'fs'

app = express.createServer(express.favicon())
store = racer.store
# The listen option accepts either a port number or a node HTTP server
racer listen: app

# racer.js returns a browserify bundle of the racer client side code and the
# socket.io client side code
script = ''
racer.js (js) -> script = js + fs.readFileSync 'client.js'
style = fs.readFileSync 'style.css'

app.get '/script.js', (req, res) ->
  res.send script, 'Content-Type': 'application/javascript'

app.get '/:room?', (req, res) ->
  # Redirect users to URLs that only contain letters, numbers, and hyphens
  room = req.params.room
  return res.redirect '/lobby' unless room && /^[-\w ]+$/.test room
  _room = room.toLowerCase().replace /[_ ]/g, '-'
  return res.redirect _room if _room != room
  
  # Subscribe optionally accepts a model as an argument. If no model is
  # specified, it will create a new model object
  store.subscribe _room: "rooms.#{room}.**", 'rooms.*.players', (err, model) ->
    model.set '_roomName', room
    initRoom model
    # model.bundle waits for any pending model operations to complete and then
    # returns a script tag with the data for initialization on the client
    model.bundle (bundle) ->
      res.send """
      <!DOCTYPE html>
      <title>Letters game</title>
      <style>#{style}</style>
      <link href=http://fonts.googleapis.com/css?family=Anton rel=stylesheet>
      <div id=back>
        <div id=page>
          <p id=info>
          <div id=rooms>
            <p>Rooms:
            <ul id=roomlist></ul>
          </div>
          <div id=board></div>
        </div>
      </div>
      <script src=/script.js></script>
      <script>racer.init(#{bundle})</script>
      """

initRoom = (model) ->
  return if model.get '_room.letters'
  colors = ['red', 'yellow', 'blue', 'orange', 'green']
  letters = {}
  for row in [0..4]
    for col in [0..25]
      letters[row * 26 + col] =
        color: colors[row]
        value: String.fromCharCode(65 + col)
        position:
          left: col * 24 + 72
          top: row * 32 + 8
  model.set '_room.letters', letters

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
