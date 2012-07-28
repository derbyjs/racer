var inspect = require('util').inspect
  , transaction = require('./transaction')
  ;

// TODO Add in ability to turn off clientId output
// TODO Add in color configuration
// TODO Add in SIGINT handlers to bump up/down logging level

exports = module.exports = plugin;
exports.decorate = 'racer';
exports.useWith = { server: true, browser: false };

/**
 * This plugin adds the methods:
 *
 * - `racer.log.incoming(clientId, message)`
 * - `racer.log.outgoing(clientId, message)`
 *
 * These methods act like `console.log` except that it adds:
 *
 * - Special indicators for incoming vs outgoing messages.
 * - Default color formatting for readability.
 *
 * The plugin re-wraps `socket.emit` and `socket.on`, so that events are
 * automatically logged. You can customize messages and formatting for these
 * auto-logged events via over-writing defaults and making additions to
 * `racer.log.incoming.events` and `racer.log.outgoing.events`.
 *
 * For example:
 *
 *     var inspect = require('util').inspect;
 *     racer.log.incoming.events.txn = function (txn) {
 *       var method = transaction.getMethod(txn);
 *       var args = transaction.getArgs(txn);
 *       return "I am a transaction: " + method + ' ' + inspect(args);
 *     };
 *
 * This will automatically intercept and log any incoming transactions over
 * socket.io to the console as:
 *
 *    some-client-id ↪ I am a transaction: set ["some.path", "someval"]
 *
 * You can do the same for outgoing events by assigning event logging handlers
 * to keys on `racer.log.outgoing.events` where the keys are named after the events.
 *
 * If you want to mute logging for a specific event, you can do so by creating
 * an event logging handler that returns false.
 *
 *     racer.log.incoming.events.txn = function (txn) {
 *       return false;
 *     };
 *
 * The code above will mute logging of "txn" events.
 *
 * If you do not define logging event handlers for a particular event, the
 * logger defaults to printing out:
 *
 *     some-client-id ↪ "event": ["arg1", 2, "arg3"]
 */
function plugin (racer) {
  var color = require('ansi-color').set
    , bold = function(value) { return color(value, 'bold'); }
    , black = function(value) { return color(value, 'black'); }
    , red = function(value) { return color(value, 'red'); }
    , green = function(value) { return color(value, 'green'); }
    , yellow = function(value) { return color(value, 'yellow'); }
    , blue = function(value) { return color(value, 'blue'); }
    , magenta = function(value) { return color(value, 'magenta'); }
    , cyan = function(value) { return color(value, 'cyan'); }
    , white = function(value) { return color(value, 'white'); }

  racer.log = function () { console.log.apply(null, args); };
  racer.log.incoming = function (clientId) {
    var args = Array.prototype.slice.call(arguments, 1);
    console.log.apply(null, [yellow(clientId), bold(blue('↩'))].concat(args));
  };
  racer.log.outgoing = function (clientId) {
    var args = Array.prototype.slice.call(arguments, 1);
    console.log.apply(null, [yellow(clientId), bold(cyan('↪'))].concat(args));
  };

  racer.log.incoming.events = {
    txn: handleTxn
  , disconnect: function (message) { return 'Disconnect' + (message ? ': ' + message : ''); }
  , derbyClient: function (appHash) { return 'Derby app with hash ' + appHash; }
  , subscribe: function (targets, contextName) { return blue('subscribe ') + joinArgs(targets); }
  , fetch: function (targets, contextName) { return blue('fetch ') + joinArgs(targets); }
  };
  racer.log.outgoing.events = {
    txnOk: function () { return false; }
  , txn: handleTxn
  , newListener: function () { return false; }
  , fatalErr: function (err) { return red('Fatal error: ' + err); }
  , "snapshotUpdate:newTxns": function () { return 'Asking client to request a snapshot update of new transactions'; }
  , resyncWithStore: function () { return 'Asking client to resync with store'; }
  , refreshHtml: function() { return 'Updating HTML templates'; }
  , refreshCss: function() { return 'Updating CSS'; }
  };
  function joinArgs (args) {
    var argStr = [];
    for (var i = 0, l = args.length; i < l; i++) {
      argStr.push(green(fullInspect(args[i])));
    }
    return argStr.join(', ');
  }
  function handleTxn (txn) {
    var ver = transaction.getVer(txn)
      , id = transaction.getId(txn)
      , args = transaction.getArgs(txn)
      , method = transaction.getMethod(txn)
    return 'ver: ' + ver + ' - ' + blue(method) + ' ' + joinArgs(args);
  }

  racer.log.sockets = function (sockets) {
    sockets.on('connection', function (socket) {
      var clientId = socket.clientId = socket.handshake.query.clientId;
      racer.log.incoming(clientId, 'Connect');

      var __emit__ = socket.emit;
      socket.emit = function (event) {
        var rest = Array.prototype.slice.call(arguments, 1)
          , handler = racer.log.outgoing.events;
        if (event in handler) {
          var out = handler[event].apply(null, rest);
          if (out !== false) racer.log.outgoing(clientId, out);
        } else {
          racer.log.outgoing.call(null, clientId, '"' + event + '":', fullInspect(rest || []));
        }
        return __emit__.apply(socket, arguments);
      }

      var __on__ = socket.on;
      socket.on = function (event, callback) {
        __on__.call(socket, event, function () {
          var args = Array.prototype.slice.call(arguments)
            , handler = racer.log.incoming.events;
          if (event in handler) {
            var out = handler[event].apply(null, args);
            if (out !== false) racer.log.incoming(clientId, out);
          } else {
            racer.log.incoming(clientId, '"' + event + '":', "\n", fullInspect(args));
          }
        });
        return __on__.apply(socket, arguments);
      };
    });
  };

  racer.mixin({
    type: 'Store'
  , events: {
      socketio: function (store, sockets) {
        racer.log.sockets(sockets);
      }
    }
  });
};

function fullInspect (x) {
  return inspect(x, false, null);
}
