fs = require 'fs'
http = require 'http'
coffeeify = require 'coffeeify'
express = require 'express'
liveDbMongo = require 'livedb-mongo'
redis = require('redis').createClient()
racerBrowserChannel = require 'racer-browserchannel'
racer = require '../../../racer'
templates = require './templates'

redis.select 13
store = racer.createStore
  db: liveDbMongo('localhost:27017/racer-todos?auto_reconnect', safe: true)
  redis: redis

app = express()
app
  .use(express.favicon())
  .use(express.compress())
  .use(express.static __dirname + '/public')
  .use(racerBrowserChannel store)
  .use(store.modelMiddleware())
  .use(app.router)

app.use (err, req, res, next) ->
  console.error err.stack || (new Error err).stack
  res.send 500, 'Something broke!'

store.on 'bundle', (browserify) ->
  browserify.add __dirname + '/public/jquery-1.9.1.min.js'
  browserify.add __dirname + '/public/jquery-ui-1.10.3.custom.min.js'
  # Add support for directly requiring coffeescript in browserify bundles
  browserify.transform coffeeify

scriptBundle = (cb) ->
  # Use Browserify to generate a script file containing all of the client-side
  # scripts, Racer, and BrowserChannel
  store.bundle __dirname + '/client.coffee', (err, js) ->
    return cb err if err
    cb null, js
# Immediately cache the result of the bundling in production mode, which is
# deteremined by the NODE_ENV environment variable. In development, the bundle
# will be recreated on every page refresh
if racer.util.isProduction
  scriptBundle (err, js) ->
    return if err
    scriptBundle = (cb) -> cb null, js

app.get '/script.js', (req, res, next) ->
  scriptBundle (err, js) ->
    return next err if err
    res.type 'js'
    res.send js

app.get '/', (req, res) ->
  res.redirect '/home'

app.get '/:groupName', (req, res, next) ->
  groupName = req.params.groupName
  # Only handle URLs that use alphanumberic characters, underscores, and dashes
  return next() unless /^[a-zA-Z0-9_-]+$/.test groupName
  # Prevent the browser from storing the HTML response in its back cache, since
  # that will cause it to render with the data from the initial load first
  res.setHeader 'Cache-Control', 'no-store'

  model = req.getModel()
  group = model.at "groups.#{groupName}"
  group.subscribe (err) ->
    return next err if err

    # Create some todos if this is a new group
    todoIds = group.at 'todoIds'
    unless todoIds.get()
      id0 = model.add 'todos', {completed: true, text: 'Done already'}
      id1 = model.add 'todos', {completed: false, text: 'Example todo'}
      id2 = model.add 'todos', {completed: false, text: 'Another example'}
      todoIds.set [id1, id2, id0]

    # Queries may be specified in terms of a Mongo query or a model path that
    # contains an id or list of ids
    model.query('todos', todoIds).subscribe (err) ->
      return next err if err

      # Create a two-way updated list with todos as items
      list = model.refList '_page.list', 'todos', todoIds
      # model.bundle waits for any pending model operations to complete and then
      # returns the JSON data for initialization on the client
      context = {list: list.get(), groupName}
      model.bundle (err, bundle) ->
        return next err if err
        context.bundle = bundle
        res.send templates.page(context)

port = process.env.PORT || 3000;
http.createServer(app).listen port, ->
  console.log 'Go to http://localhost:' + port
