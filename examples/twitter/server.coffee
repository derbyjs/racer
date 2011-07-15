rally = require 'rally'
express = require 'express'
fs = require 'fs'

store = rally.store
app = express.createServer(
  express.bodyParser(),
  express.cookieParser(),
  express.session secret: 'shhhh_dont_tell',
  rally ioPort: 3001
)

app.get '/', (req, res) ->
  model = req.model
  if model.get '_session.user'
    # If the user is signed in, show their stream
    
    return res.send ...
  # Otherwise, show a sign-in page

app.post '/signin', (req, res) ->
  {username, password} = req.param
  path = 'users.' + username
  store.subscribe path, (err, model, value) ->
    if value && value.password == password
      model.set '_session',
        user: model.ref path
        stream: 
      req.model = model
      return res.redirect '/'
    res.send 'Sign in failed'

app.post '/users/new', (req, res) ->
  user =
    username: username = req.param.username
    password: req.param.password
    email: req.param.email
  path = 'users.' + username
  # Add the new user data if the username is not taken
  store.get path, (err, value, ver) ->
    if !err && value == undefined
      store.set path, user, ver, (err) ->
        return res.send 'Success' unless err
    return 'Username taken'
