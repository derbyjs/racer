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

store.on 'push', 'updates', (update, length) ->
  # When a new update is added, reference any mentioned users to the update
  for mention in update.match /@[^ ]+/g
    username = mention.substr 1
    store.set "users.#{username}.mentionIds.#{length - 1}", true

app.get '/', (req, res) ->
  model = req.model
  if model.get '_session.user'
    # If the user is signed in, show their stream
    
    return res.send 'TODO'
  # Otherwise, show a sign-in page
  
  res.send 'TODO'

stream = (followingIds, callback) ->
  # Store.query provides a database specific interface scoped to a
  # model path. This example assumes MongoDB
  authors = {author: id} for id in followingIds
  store.query('updates').limit(20).find $or: authors, callback

app.post '/account/signin', (req, res) ->
  {username, password} = req.param
  userPath = 'users.' + username
  store.subscribe userPath, (err, model, value) ->
    if value && value.password == password
      model.set '_session',
        user: model.ref userPath
        # If a number is passed as the first argument to a model function
        # generator, the function is re-evaluated on an iterval. Otherwise,
        # the function is re-evaluated every time the value of one of its
        # inputs changes.
        stream: model.remoteFn 1000, '_session.user.followingIds', stream
        mentions: model.ref 'updates', '_session.user.mentionIds'
      req.model = model
      return res.redirect '/'
    res.send 'sign in failed'

app.post '/users/new', (req, res) ->
  user =
    username: username = req.param.username
    password: req.param.password
    email: req.param.email
    updateIds: {}
    followingIds: {}
    mentionIds: {}
  # Add the new user data if the username is not taken
  userPath = "users.#{username}"
  store.get userPath, (err, value, ver) ->
    if !err && value == undefined
      store.set userPath, user, ver, (err) ->
        return res.send 'success' unless err
    return 'username taken'

# TODO: This should be in client code actually
app.post '/users/follow', (req, res) ->
  followingPath = '_session.user.followingIds'
  if req.model.get followingPath
    req.model.set "#{followingPath}.#{req.param.followUsername}", true
    return res.send 'success'
  res.redirect '/'
