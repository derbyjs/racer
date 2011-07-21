rally = require 'rally'
express = require 'express'
fs = require 'fs'

rally ioPort: 3001
store = rally.store
app = express.createServer()

# rally.js returns a browserify bundle of the rally client side code and the
# socket.io client side code
script = rally.js() + fs.readFileSync 'client.js'
style = fs.readFileSync 'style.css'

app.get '/script.js', (req, res) ->
  res.send script, 'Content-Type': 'application/javascript'

app.get '/:room', (req, res) ->
  room = req.params.room || 'default'
  # Subscribe optionally accepts a model as an argument. If no model is
  # specified, it will create a new model object
  store.subscribe "#{room}.letters.*", "#{room}.info.*", (err, model) ->
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
  populateRoom 'default'
  app.listen 3000

populateRoom = (room) ->
  store.get "#{room}.letters", (err, val) ->
    throw err if err
    return if val

    players = 0
    updatePlayers = -> store.set "#{room}.info.players", players
    players = 0; updatePlayers()
    rally.sockets.on 'connection', (socket) ->
      players++; updatePlayers()
      socket.on 'disconnect', ->
        players--; updatePlayers()

    colors = ['red', 'yellow', 'blue', 'orange', 'green']
    letters = {}
    for row in [0..4]
      for col in [0..25]
        letters[row * 26 + col] =
          color: colors[row]
          value: String.fromCharCode(65 + col)
          left: col * 24 + 72
          top: row * 32 + 8
    store.set "#{room}.letters", letters


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
