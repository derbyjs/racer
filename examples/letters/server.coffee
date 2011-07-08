rally = require 'rally'
rallyMongo = require 'rally-mongodb'
express = require 'express'
fs = require 'fs'

# Follows the same middleware interface as Connect:
rally.use rallyMongo
  server: 'mongodb://localhost/rally-letters'
  load: (done) ->
    store = rally.store
    store.get 'letters', (err, letters) ->
      return done err if err or letters
      # Initialize data if letters object has not been created
      colors = ['red', 'yellow', 'blue', 'orange', 'green']
      letters = {}
      for row in [0..4]
        for col in [0..25]
          letters[row * 26 + col] =
            color: colors[row]
            value: String.fromCharCode(65 + col)
            left: col * 24 + 72
            top: row * 32 + 8
      store.set 'letters', letters, done

# TODO Pass in Socket.IO configuration params

app = express.createServer()

app.get '/', (req, res) ->
  fs.readFile 'client.js', 'utf8', (err, clientScript) ->
    fs.readFile 'style.css', 'utf8', (err, style) ->
      # Subscribe optionally accepts a model as an argument. If no model is
      # specified, it will create a new model object.
      rally.subscribe 'letters', (err, model) ->
        modelScript = model.js()
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
        <script>#{modelScript + clientScript}</script>
        """

app.listen 3000
