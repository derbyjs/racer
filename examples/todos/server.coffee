racer = require 'racer'
express = require 'express'
fs = require 'fs'
client = require './client'

app = express.createServer express.favicon(), express.static(__dirname)
racer listen: app

# racer.js returns a browserify bundle of the racer client side code and the
# socket.io client side code
racer.js (js) -> fs.writeFileSync 'script.js', js + fs.readFileSync('client.js')

app.get '/', (req, res) ->
  res.redirect '/racer'

app.get '/:group', (req, res) ->
  group = req.params.group
  racer.store.subscribe _group: "groups.#{group}.**", (err, model) ->
    initGroup model
    # Currently, refs must be explicitly declared per model; otherwise the ref
    # is not added the model's internal reference indices
    model.set '_group.todoList', model.arrayRef '_group.todos', '_group.todoIds'
    model.bundle (bundle) ->
      listHtml = (client.todoHtml todo for todo in model.get '_group.todoList').join('')
      res.send """
      <!DOCTYPE html>
      <title>Todo list</title>
      <link rel=stylesheet href=style.css>
      <body>
      <form id=head action=javascript:addTodo()>
        <h1>Todos</h1>
        <div id=add><div id=add-input><input id=new-todo></div><input id=add-button type=submit value=Add></div>
      </form>
      <div id=dragbox></div>
      <div id=content><ul id=todos>#{listHtml}</ul></div>
      <script src=https://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery.min.js></script>
      <script src=https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.15/jquery-ui.min.js></script>
      <script src=/script.js></script>
      <script>racer.init(#{bundle})</script>
      """

initGroup = (model) ->
  return if model.get '_group'
  model.set '_group.todos',
    0: {id: 0, completed: true, text: 'This one is done already'}
    1: {id: 1, completed: false, text: 'Example todo'}
    2: {id: 2, completed: false, text: 'Another example'}
  model.set '_group.todoIds', [1, 2, 0]
  model.set '_group.nextId', 3

# Clear any existing data, then initialize
racer.store.flush (err) ->
  throw err if err
  app.listen 3000
  console.log "Go to http://localhost:3000/racer"
