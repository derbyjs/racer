{app, racer} = require './index'
app.listen 3001
racer.listen app
console.log 'Go to http://localhost:3001/todos/racer'
