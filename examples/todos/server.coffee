rally = require 'rally'
express = require 'express'
fs = require 'fs'

rally ioPort: 3001
store = rally.store
app = express.createServer(
    express.bodyParser()
  , express.cookieParser()
  , express.session secret: 'shhhh_dont_tell'
  , rally()
)

Model = store.Model
User = Model.subclass
  username: String

Group = Model.subclass
  name: String
  todos: [Todo]

Todo = Model.subclass
  label: String
  completed: Date

# rally.js returns a browserify bundle of the rally client side code and the
# socket.io client side code
script = rally.js() + fs.readFileSync 'client.js'
style = fs.readFileSync 'style.css'

app.get '/script.js', (req, res) ->
  res.send script, 'Content-Type': 'application/javascript'

userCount = 1

app.get '/', (req, res) ->
  # user is a promise/future
  unless userId = req.session.userId
    user = User.create username: 'user_' + userCount++
  else
    user = User.findById userId
  # group is also a promise/future
  group = Group.findById groupId

  # subscribe waits for the promises to complete.
  # user.name, group.todos, and group.name also are promises.
  # subscribe analyzes the eventually promise-fetched snapshots'
  # versions and then catches the versions up + subscribes for
  # future updates to all paths corresponding to user,
  # group, and used properties.
  store.subscribe user.name, group.todos, group.name, (err, model) ->
    # model.json waits for any pending model operations to complete and then
    # returns the data for initialization on the client
    model.json (json) ->
      res.send """
      <!DOCTYPE html>
      <title>Letters game</title>
      <style>#{style}</style>
      <link href=http://fonts.googleapis.com/css?family=Anton&v1 rel=stylesheet>
      <div id=container>
        <h1>Todos</h1>
        <form><input class="new-item" value="add a todo item" /></form>
        <ul id="items">
          <li>
            <input type="checkbox" />
            <label>Some Existing Todo Item</label>
            <a>delete</a>
          </li>
        </ul>
      </div>
      <script src=/script.js></script>
      <script>rally.init(#{json})</script>
      """

# Clear any existing data, then initialize
store.flush (err) ->
  throw err if err
  app.listen 3000
