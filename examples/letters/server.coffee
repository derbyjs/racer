rally = require 'rally'
express = require 'express'
fs = require 'fs'

rally ioPort: 3001
store = rally.store
presence = rally.presence
app = express.createServer()
app.use express.favicon()

# rally.js returns a browserify bundle of the rally client side code and the
# socket.io client side code
script = rally.js() + fs.readFileSync 'client.js'
style = fs.readFileSync 'style.css'

app.get '/script.js', (req, res) ->
  res.send script, 'Content-Type': 'application/javascript'

app.get '/', (req, res) ->
  res.redirect '/default'

app.get '/:room', (req, res) ->
  room = req.params.room
  populateRoom room, (err) ->
    throw err if err
    # Subscribe optionally accepts a model as an argument. If no model is
    # specified, it will create a new model object
    store.subscribe "#{room}.letters.*", "info.*", (err, model) ->
      # model.json waits for any pending model operations to complete and then
      # returns the data for initialization on the client
      model.json (json) ->
        res.send """
        <!DOCTYPE html>
        <title>Letters game</title>
        <style>#{style}</style>
        <link href=http://fonts.googleapis.com/css?family=Anton&v1 rel=stylesheet>
        <div id=back>
          <div id=page>
            <p id=info>
            <div id=board></div>
          </div>
        </div>
        <script src=/script.js></script>
        <script>rally.init(#{json})</script>
        """

# Clear any existing data, then initialize
store.flush (err) ->
  # TODO Once presence feature is implemented, change players
  #      from total global players to total players in a room
  updatePlayers = -> store.set 'info.players', players
  players = 0; updatePlayers()
  rally.sockets.on 'connection', (socket) ->
    players++; updatePlayers()
    socket.on 'disconnect', ->
      players--; updatePlayers()
  app.listen 3000
  console.log "Go to http://localhost:3000/"
  console.log "Go to http://localhost:3000/nates_room"
  console.log "Go to http://localhost:3000/brians_room"

populateRoom = (room, callback) ->
  store.get "#{room}.letters", (err, val) ->
    throw err if err
    return callback null if val

    colors = ['red', 'yellow', 'blue', 'orange', 'green']
    letters = {}
    for row in [0..4]
      for col in [0..25]
        letters[row * 26 + col] =
          color: colors[row]
          value: String.fromCharCode(65 + col)
          left: col * 24 + 72
          top: row * 32 + 8
    store.set "#{room}.letters", letters, null, callback

  # # Follows the same middleware interface as Connect:
  # rally.use rallyMongo
  #   server: 'mongodb://localhost/rally-letters'
  #   load: () ->
  #     store = rally.store
  #     store.get 'letters', (err, letters) ->
  #       return if err or letters
  #       # Initialize data if letters object has not been created
  #       colors = ['red', 'yellow', 'blue', 'orange', 'green']
  #       letters = {}
  #       for row in [0..4]
  #         for col in [0..25]
  #           letters[row * 26 + col] =
  #             color: colors[row]
  #             value: String.fromCharCode(65 + col)
  #             left: col * 24 + 72
  #             top: row * 32 + 8
  #       store.set 'letters', letters

  # Follows the same middleware interface as Connect:
