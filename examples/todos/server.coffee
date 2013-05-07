fs = require 'fs'
http = require 'http'
coffeeify = require 'coffeeify'
express = require 'express'
racer = require '../../lib/racer'
templates = require './templates'

app = express()
server = http.createServer app
store = racer.createStore
  server: server
  db: racer.db.mongo 'localhost:27017/test?auto_reconnect', safe: true

app
  .use(express.favicon())
  .use(express.static __dirname + '/public')
  .use(store.socketMiddleware())
  .use(store.modelMiddleware())

# Add support for directly requiring coffeescript in browserify bundles
racer.on 'beforeBundle', (browserify) ->
  browserify.transform coffeeify

app.get '/script.js', (req, res, next) ->
  racer.bundle __dirname + '/client.coffee', (err, js) ->
    return next err if err
    res.type 'js'
    res.send js

app.get '/', (req, res) ->
  res.redirect '/racer'

app.get '/:groupName', (req, res, next) ->
  groupName = req.params.groupName
  # Only handle URLs that use alphanumberic characters, underscores, and dashes
  return next() unless /^[a-zA-Z0-9_-]+$/.test groupName
  model = req.getModel()
  group = model.at "groups.#{groupName}"
  model.subscribe group, (err) ->
    return next err if err
    # Create some todos if this is a new group
    unless group.get 'todoIds'
      id0 = group.add 'todos', {completed: true, text: 'Done already'}
      id1 = group.add 'todos', {completed: false, text: 'Example todo'}
      id2 = group.add 'todos', {completed: false, text: 'Another example'}
      group.set 'todoIds', [id1, id2, id0]
    model.ref '_group', group
    todosQuery.refList '_page.todoList', group.at('todos'), group.at('todoIds')
    # model.bundle waits for any pending model operations to complete and then
    # returns the JSON data for initialization on the client
    model.bundle (err, bundle) ->
      return next err if err
      todos = model.get '_page.todoList'
      res.send templates.page({todos, bundle})

port = process.env.PORT || 3000;
server.listen port, ->
  console.log 'Go to http://localhost:' + port
