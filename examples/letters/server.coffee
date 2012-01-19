express = require 'express'
gzip = require 'connect-gzip'
fs = require 'fs'
racer = require 'racer'

app = express.createServer()
  .use(express.favicon())
  .use(gzip.staticGzip(__dirname))

store = racer.createStore
  redis: {db: 10}       # Configuration options for Redis transaction journal
  listen: app           # A port or http server
  namespace: 'letters'  # Socket.IO namespace
  stm: true             # Enable STM conflict detection. Last-writer-wins by default

# Clear all existing data on restart
store.flush()

# racer.js returns a browserify bundle of the racer client side code and the
# socket.io client side code as well as any additional browserify options
racer.js entry: __dirname + '/client.js', (js) ->
  fs.writeFileSync __dirname + '/script.js', js
  
colors = ['red', 'yellow', 'blue', 'orange', 'green']
defaultLetters = {}
for row in [0..4]
  for col in [0..25]
    defaultLetters[row * 26 + col] =
      color: colors[row]
      value: String.fromCharCode(65 + col)
      position:
        left: col * 24 + 72
        top: row * 32 + 8
# Use JSON serialization to create a deep clone
defaultLetters = JSON.stringify defaultLetters

app.get '/:room?', (req, res) ->
  # Redirect users to URLs that only contain letters, numbers, and hyphens
  room = req.params.room
  return res.redirect '/lobby' unless room && /^[-\w ]+$/.test room
  _room = room.toLowerCase().replace /[_ ]/g, '-'
  return res.redirect "/#{_room}" if _room != room
  
  model = store.createModel()
  model.subscribe _room: "rooms.#{room}", 'rooms.*.players', ->
    unless model.get '_room.letters'
      model.set '_room.letters', JSON.parse defaultLetters
    model.set '_roomName', room
    # model.bundle waits for any pending model operations to complete and then
    # returns the JSON data for initialization on the client
    model.bundle (bundle) ->
      boardHtml = ''
      if ~ req.headers['user-agent'].indexOf 'MSIE'
        # If IE, use a link element, since only images and links can be dragged
        open = '<a href=# onclick="return false"'
        close = '</a>'
      else
        open = '<span'
        close = '</span>'
      for id, letter of model.get "_room.letters"
        boardHtml += """#{open} draggable=true class="#{letter.color} letter" id=#{id}
        style=left:#{letter.position.left}px;top:#{letter.position.top}px>#{letter.value}#{close}"""
      res.send """
      <!DOCTYPE html>
      <title>Letters game</title>
      <link rel=stylesheet href=style.css>
      <link rel=stylesheet href="http://fonts.googleapis.com/css?family=Anton">
      <div id=back>
        <div id=page>
          <p id=info>
          <div id=rooms>
            <p>Rooms:
            <ul id=roomlist></ul>
          </div>
          <div id=board>#{boardHtml}</div>
        </div>
      </div>
      <script>init=#{bundle}</script>
      <script src=script.js></script>
    """

store.sockets.on 'connection', (socket) ->
  socket.on 'join', (room) ->
    playersPath = "rooms.#{room}.players"
    store.incr playersPath
    socket.on 'disconnect', -> store.incr playersPath, -1

app.listen 3010
console.log 'Go to http://localhost:3010/lobby'
console.log 'Go to http://localhost:3010/powder-room'
