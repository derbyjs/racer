racer = require 'racer'
express = require 'express'
fs = require 'fs'

exports.app = app = express.createServer express.favicon(), express.static(__dirname)
# The listen option accepts either a port number or a node HTTP server
racer listen: app

exports.store = store = racer.store

# racer.js returns a browserify bundle of the racer client side code and the
# socket.io client side code
racer.js (js) -> fs.writeFileSync 'script.js', js + fs.readFileSync('client.js')

app.get '/:room?', (req, res) ->
  # Redirect users to URLs that only contain letters, numbers, and hyphens
  room = req.params.room
  return res.redirect '/lobby' unless room && /^[-\w ]+$/.test room
  _room = room.toLowerCase().replace /[_ ]/g, '-'
  return res.redirect _room if _room != room
  
  store.subscribe _room: "rooms.#{room}.**", 'rooms.*.players', (err, model) ->
    model.set '_roomName', room
    initRoom model
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
      <link rel=stylesheet href=http://fonts.googleapis.com/css?family=Anton>
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

