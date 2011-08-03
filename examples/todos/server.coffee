rally = require 'rally'
express = require 'express'
fs = require 'fs'

rally ioPort: 3001
store = rally.store
app = express.createServer(
  express.favicon(),
  express.bodyParser(),
  express.cookieParser(),
  express.session secret: 'shhhh_dont_tell'
)

# rally.js returns a browserify bundle of the rally client side code and the
# socket.io client side code
script = ''
rally.js (js) -> script = js + fs.readFileSync 'client.js'
style = fs.readFileSync 'style.css'

app.get '/script.js', (req, res) ->
  res.send script, 'Content-Type': 'application/javascript'

userCount = 0

app.get '/', (req, res) ->
  res.redirect '/rally'

app.get '/:groupId', (req, res) ->
  groupId = req.params.groupId
  store.subscribe "groups.#{groupId}.*", (err, model) ->
    if !model.get "groups.#{groupId}.*"
      model.set "groups.#{groupId}", { id: groupId }
      model.set "groups.#{groupId}.todos", model.ref('todos', "groups.#{groupId}.todoIds")

    # user is a promise/future
    unless userId = req.session.userId
      model.set "users.#{userId = ++userCount}", { id: userId }
      model.set "users.#{userId}.todos", model.ref('todos', "users.#{userId}.todoIds")
      req.session.userId = userId
    store.subscribe model, "users.#{userId}.*"
    model.json (json) ->
      res.send """
      <!DOCTYPE html>
      <title>Todo list</title>
      <style>#{style}</style>
      <div id=container>
        <h1>Todos</h1>
        <form><input id=new-todo><input type=submit value=Add></form>
        <ul id=todos></ul>
      </div>
      <script src=/script.js defer></script>
      <script>window.onload=function(){rally.init(#{json})}</script>
      """
# Clear any existing data, then initialize
store.flush (err) ->
  throw err if err
  app.listen 3000
  console.log "Go to http://localhost:3000/rally"
