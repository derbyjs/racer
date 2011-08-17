{app, store} = require './index'

# Clear any existing data, then initialize
store.flush (err) ->
  throw err if err
  app.listen 3000
  console.log 'Go to http://localhost:3000/letters/lobby'
  console.log 'Go to http://localhost:3000/letters/powder-room'

