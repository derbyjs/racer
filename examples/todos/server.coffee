{app, store} = require './index'

# Clear any existing data, then initialize
store.flush (err) ->
  throw err if err
  app.listen 3001
  console.log 'Go to http://localhost:3001/todos/racer'

