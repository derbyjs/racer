var transaction = require('../transaction.server')
  , Serializer = require('../Serializer')
  , shared = require('./shared')
  , createJournal = shared.createJournal
  , createStartIdVerifier = shared.createStartIdVerifier
  ;

module.exports = function (storeOptions) {
  var journal = createJournal(storeOptions);
  return new Stm(storeOptions.store, journal);
};

function Stm (store, journal) {
  this._store = store;
  this._journal = journal;

  /* Ensure Serialization of Transactions to the DB */
  // TODO This algorithm will need to change when we go multi-process, because
  // we can't count on the version to increase sequentially
  this._txnApplier = new Serializer({
    withEach: function (txn, ver, cb) {
      // store._finishCommit(txn, ver, cb);
      cb();
    }
  });

  // The server journal generates a startId, as a reference point for racer to
  // detect if the server journal has crashed. If the journal crashed, it may
  // have lost transactions that the system had already accepted as committed
  // (and therefore that the client will have already applied). This leads to
  // invalid state because our client thinks its data has been accepted by the
  // server; meanwhile, the server could be receiving and committing
  // transactions that effectively use the same sequence of versions as these
  // prior-accepted transactions. Therefore, there would be a fork of accepted
  // states.
  // TODO: Map the client's version number to the journal's and update
  // the client with the new startId & version when possible
  this.startIdVerifier = createStartIdVerifier( function (cb) {
    journal.startId(cb);
  });

  this.detectConflict = this.detectConflict.bind(this);
  this.addToJournal   = this.addToJournal.bind(this);
  this.incrVer        = this.incrVer.bind(this);
}

Stm.prototype.startId = function (cb) {
  this._journal.startId(cb);
};

Stm.prototype.detectConflict = function (req, res, next) {
  var txn = req.data;
  var ver = transaction.getVer(txn);
  var eachCb;
  if (ver != null) {
    if (typeof ver !== 'number') {
      // In case of something like store.set(path, value, cb)
      return res.fail('Version must be null or a number');
    }
    eachCb = function (err, loggedTxn, next) {
      if (ver != null && (err = transaction.conflict(txn, loggedTxn))) {
        return next(err);
      }
      next(null);
    }
  } else {
    eachCb = next;
  }

  this._journal.eachTxnSince(ver, {
    meta: {txn: txn}
  , each: eachCb
  , done: function (err, addParams) {
      if (err) return res.fail(err);
      req.addParams = addParams;
      return next();
    }
  });
};

Stm.prototype.addToJournal = function (req, res, next) {
  var txn = req.data
    , addParams = req.addParams
    , journalTxn = copy(txn)
    , self = this;

  this._journal.add(journalTxn, addParams, function (err, ver) {
    if (err) return res.fail(err);

    // TODO Remove this line?
    transaction.setVer(journalTxn, ver);

    req.newVer = ver;

    self._txnApplier.add(txn, ver, function (err) {
      if (err) return res.fail(err);
      next();
    });
  });
};

Stm.prototype.incrVer = function (req, res, next) {
  var txn = req.data;
  transaction.setVer(txn, req.newVer);
  next();
};

Stm.prototype.flush = function (cb) {
  this._journal.flush(cb);
};

Stm.prototype.disconnect = function () {
  var journal = this._journal;
  journal.disconnect && journal.disconnect();
};

Stm.prototype.version = function (cb) {
  this._journal.version(cb);
};

Stm.prototype.snapshotSince = function (params, cb) {
  var ver = params.ver
    , clientId = params.clientId;
  this._journal.txnsSince(ver, clientId, this._store._pubSub, function (err, txns) {
    if (err) return cb(err);
    cb(null, {txns: txns});
  });
};

function copy (x) {
  return JSON.parse(JSON.stringify(x));
}
