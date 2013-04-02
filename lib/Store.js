var Duplex = require('stream').Duplex;
var browserChannel = require('browserchannel').server;
var share = require('share');
var Model = require('./Model')

module.exports = Store;

/**
 * [Store description]
 * @constructor
 */
function Store() {}

Store.prototype.shareMiddleware = function(options) {
  var server = options.server;

  var shareClient = share.createClient({
    db: options.db
  // , auth: myauthfn
  });

  var middleware = browserChannel({server: server}, function(client) {
    var stream = new Duplex({objectMode: true});
    
    stream._write = function _write(chunk, encoding, callback) {
      console.log('s->c ', chunk);
      client.send(chunk);
      callback();
    };
    stream._read = function _read() {
      // Ignore. You can't control the information, man!
    };

    client.on('message', function onMessage(data) {
      console.log('c->s ', data);
      stream.push(data);
    });

    stream.on('error', function onError(msg) {
      client.stop();
    });

    // ... and give the stream to ShareJS.
    shareClient.listen(stream);
  });
  return middleware;
};

Store.prototype.createModel = function() {
  var model = new Model();
  return model;
};
