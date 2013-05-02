var http = require('http');
var fs = require('fs');
var express = require('express');
var handlebars = require('handlebars');
var racer = require('../../lib/racer');
var share = require('share');

var app = express()
  .use(express.favicon())

var server = http.createServer(app);
var store = racer.createStore({
  server: server
, db: share.db.mongo('localhost:27017/test?auto_reconnect', {safe: true})
});

app.use(store.socketMiddleware());

app.get('/script.js', function(req, res) {
  racer.bundle(__dirname + '/client.js', function(err, js) {
    res.type('js');
    res.send(js);
  });
});

app.get('/:roomId', function(req, res, next) {
  var model = store.createModel();
  var index = fs.readFileSync(__dirname + '/index.handlebars', 'utf-8');
  var indexTemplate = handlebars.compile(index);

  var roomId = req.params.roomId;
  var roomQuery = model.query('rooms', {_id:roomId});
  roomQuery.subscribe(function(err) {
    if (err) return next(err);

    model.ref('_room', 'rooms.' + roomId);

    model.bundle(function(err, bundle) {
      if (err) return next(err);
      var html = indexTemplate({
        text: model.get('_room')
      , bundle: bundle.replace(/<\//g, '<\\/')
      });
      res.send(html);
    });
  })
});

app.get('/', function(req, res) {
  res.redirect('/home');
});

var port = process.env.PORT || 3000;
server.listen(port, function() {
  console.log("Go to http://localhost:" + port);
});
