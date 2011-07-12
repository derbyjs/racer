rally = require 'rally'
express = require 'express'
fs = require 'fs'

rally ioPort: 3001
app = express.createServer()

# rally.js returns a browserify bundle of the rally client side code and the
# socket.io client side code
script = rally.js() + fs.readFileSync 'client.js'
style = fs.readFileSync 'style.css'

app.get '/script.js', (req, res) -> res.send script

app.get '/', (req, res) ->
  # Subscribe optionally accepts a model as an argument. If no model is
  # specified, it will create a new model object
  rally.subscribe ['letters', 'info'], (err, model) ->
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

connectionCount = 0
updateConnected = -> rally.store.set 'info.connected', connectionCount
rally.sockets.on 'connection', (socket) ->
  connectionCount++
  updateConnected()
  socket.on 'disconnect', ->
    connectionCount--
    updateConnected()

# Clear any existing data, then initialize
rally.store.flush ->
  colors = ['red', 'yellow', 'blue', 'orange', 'green']
  letters = {}
  for row in [0..4]
    for col in [0..25]
      letters[row * 26 + col] =
        color: colors[row]
        value: String.fromCharCode(65 + col)
        left: col * 24 + 72
        top: row * 32 + 8
  rally.store.set 'letters', letters, (err) ->
    throw err if err
    app.listen 3000

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
