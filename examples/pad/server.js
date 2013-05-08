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
  .use(express.compress())
  .use(app.router)

app.use(function(err, req, res, next) {
  console.error(err.stack || (new Error(err)).stack);
  res.send(500, 'Something broke!');
});

function scriptBundle(cb) {
  // Use Browserify to generate a script file containing all of the client-side
  // scripts, Racer, and BrowserChannel
  store.bundle(__dirname + '/client.js', function(err, js) {
    if (err) return cb(err);
    // Cache the result of the first bundling in production mode, which is
    // deteremined by the NODE_ENV environment variable
    if (racer.util.isProduction) {
      scriptBundle = function(cb) {
        cb(null, js);
      };
    }
    cb(null, js);
  });
}

app.get('/script.js', function(req, res, next) {
  scriptBundle(function(err, js) {
    if (err) return next(err);
    res.type('js');
    res.send(js);
  });
});

var indexTemplate = fs.readFileSync(__dirname + '/index.handlebars', 'utf-8');
var indexPage = handlebars.compile(indexTemplate);

app.get('/:roomId', function(req, res, next) {
  var model = req.getModel();
  // Only handle URLs that use alphanumberic characters, underscores, and dashes
  if (!/^[a-zA-Z0-9_-]+$/.test(req.params.roomId)) return next();

  var roomPath = 'rooms.' + req.params.roomId;
  model.subscribe(roomPath, function(err) {
    if (err) return next(err);

    model.ref('_room', roomPath);
    model.bundle(function(err, bundle) {
      if (err) return next(err);
      var html = indexPage({
        text: model.get(roomPath)
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
