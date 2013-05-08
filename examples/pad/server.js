var fs = require('fs');
var http = require('http');
var express = require('express');
var handlebars = require('handlebars');
var racer = require('../../../racer');

var app = express();
var server = http.createServer(app);
var store = racer.createStore({
  server: server
, db: racer.db.mongo('localhost:27017/test?auto_reconnect', {safe: true})
});

store
  .use(require('racer-browserchannel'))

app
  .use(express.favicon())
  .use(store.socketMiddleware())
  .use(store.modelMiddleware())
  .use(app.router)

app.use(function(err, req, res, next) {
  console.error(err.stack || (new Error(err)).stack);
  res.send(500, 'Something broke!');
});

app.get('/script.js', function(req, res, next) {
  store.bundle(__dirname + '/client.js', function(err, js) {
    if (err) return next(err);
    res.type('js');
    res.send(js);
  });
});

var indexTemplate = fs.readFileSync(__dirname + '/index.handlebars', 'utf-8');
var indexPage = handlebars.compile(indexTemplate);

app.get('/:roomId', function(req, res, next) {
  var model = req.getModel();

  var roomPath = 'rooms.' + req.params.roomId;
  model.subscribe(roomPath, function(err) {
    if (err) return next(err);

    model.ref('_room', roomPath);
    model.stringInsert('_room', 0, '!')
    model.bundle(function(err, bundle) {
      if (err) return next(err);
      var html = indexPage({
        text: model.get('_room')
      , bundle: JSON.stringify(bundle).replace(/<\//g, '<\\/')
      });
      res.send(html);
    });
  });
});

app.get('/', function(req, res) {
  res.redirect('/home');
});

var port = process.env.PORT || 3000;
server.listen(port, function() {
  console.log('Go to http://localhost:' + port);
});
