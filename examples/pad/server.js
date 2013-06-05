var fs = require('fs');
var http = require('http');
var express = require('express');
var handlebars = require('handlebars');
var liveDbMongo = require('livedb-mongo');
var redis = require('redis').createClient();
var racerBrowserChannel = require('racer-browserchannel');
var racer = require('../../../racer');

redis.select(14);
var store = racer.createStore({
  db: liveDbMongo('localhost:27017/racer-pad?auto_reconnect', {safe: true})
, redis: redis
});

app = express();
app
  .use(express.favicon())
  .use(express.compress())
  .use(racerBrowserChannel(store))
  .use(store.modelMiddleware())
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
    cb(null, js);
  });
}
// Immediately cache the result of the bundling in production mode, which is
// deteremined by the NODE_ENV environment variable. In development, the bundle
// will be recreated on every page refresh
if (racer.util.isProduction) {
  scriptBundle(function(err, js) {
    if (err) return;
    scriptBundle = function(cb) {
      cb(null, js);
    };
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
  // Prevent the browser from storing the HTML response in its back cache, since
  // that will cause it to render with the data from the initial load first
  res.setHeader('Cache-Control', 'no-store');

  var roomPath = 'rooms.' + req.params.roomId;
  model.subscribe(roomPath, function(err) {
    if (err) return next(err);

    model.ref('_page.room', roomPath);
    model.bundle(function(err, bundle) {
      if (err) return next(err);
      var html = indexPage({
        room: req.params.roomId
      , text: model.get(roomPath)
        // Escape bundle for use in an HTML attribute in single quotes, since
        // JSON will have lots of double quotes
      , bundle: JSON.stringify(bundle).replace(/'/g, '&#39;')
      });
      res.send(html);
    });
  });
});

app.get('/', function(req, res) {
  res.redirect('/home');
});

var port = process.env.PORT || 3000;
http.createServer(app).listen(port, function() {
  console.log('Go to http://localhost:' + port);
});
