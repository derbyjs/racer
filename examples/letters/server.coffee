{app, racer} = require('./index')
app.listen 3000
racer.listen app
console.log 'Go to http://localhost:3000/letters/lobby'
console.log 'Go to http://localhost:3000/letters/powder-room'
