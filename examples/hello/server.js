var http = require('http');
var fs = require('fs');
var express = require('express');
var handlebars = require('handlebars');
var racer = require('../../lib/racer');
var share = require('share')

var app = express()
  .use(express.favicon())

var server = http.createServer(app);
var store = racer.createStore({
  server: server
, db: share.db.mongo('localhost:27017/test?auto_reconnect', {safe: true})
});

app.use(store.socketMiddleware());

var index = fs.readFileSync(__dirname + '/index.handlebars', 'utf-8');
var indexTemplate = handlebars.compile(index);

app.get('/script.js', function(req, res) {
  racer.js({
    entry: __dirname + '/client.js'
  }, function(err, js) {
    res.type('js');
    res.send(js);
  });
});

app.get('/', function(req, res, next) {
  var model = store.createModel();
  model.bundle(function(err, bundle) {
    if (err) return next(err);
    var html = indexTemplate({bundle: bundle});
    res.send(html);
  });
});

server.listen(3013, function() {
  console.log('Go to http://localhost:3013/');
});
