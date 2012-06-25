var inspect = require('util').inspect
  , transaction = require('./transaction')
  ;

// TODO Add in SIGINT handlers to bump up/down logging level

require('colors');

exports = module.exports = plugin;
exports.decorate = 'racer';
exports.useWith = { server: true, browser: false };

function plugin (racer) {
  racer.log = function () { console.log.apply(null, args); };
  racer.log.incoming = function (clientId) {
    var args = Array.prototype.slice.call(arguments, 1);
    console.log.apply(null, [clientId.yellow, '↪'.cyan].concat(args));
  };
  racer.log.outgoing = function (clientId) {
    var args = Array.prototype.slice.call(arguments, 1);
    console.log.apply(null, [clientId.yellow, '↩'.green].concat(args));
  };
  racer.log.incoming.events = {
    txn: function (txn) {
      var ver = transaction.getVer(txn)
        , id = transaction.getId(txn)
        , args = transaction.getArgs(txn)
        , method = transaction.getMethod(txn)
        , out = method.blue + ' '
        , argStr = [];
      for (var i = 0, l = args.length; i < l; i++) {
        argStr.push(fullInspect(args[i]).green);
      }
      out += argStr.join(', ') + ' ';
      return out;
    }
  , disconnect: function (message) { return ('disconnect: ' + (message ? message : '')).red; }
  };
  racer.log.outgoing.events = {
    txnOk: function () { return false; }
  , newListener: function () { return false; }
  , fatalErr: function (err) { return ('FATAL ERR: ' + err).red; }
  , "snapshotUpdate:newTxns": function () { return 'Asking client to ask store for a snapshot update of new transactions'.green; }
  , resyncWithStore: function () { return 'Asking client to resync with store'.green; }
  };

  racer.log.sockets = function (sockets) {
    sockets.on('connection', function (socket) {
      var clientId = socket.clientId = socket.handshake.query.clientId;
      racer.log.incoming(clientId, 'connected'.green);

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
};

function fullInspect (x) {
  return inspect(x, false, null);
}
