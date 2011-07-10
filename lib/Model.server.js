module.exports = {
  _setStm: function(stm) {
    var onTxn;
    onTxn = this._onTxn;
    return this._send = function(txn) {
      return stm.commit(txn, function(err, ver) {
        if (ver) {
          txn[0] = ver;
          onTxn(txn);
        }
        return true;
      });
    };
  },
  json: function() {
    return JSON.stringify({
      data: this._data,
      base: this._base,
      clientId: this._clientId,
      txnCount: this._txnCount,
      ioUri: this._ioUri
    });
  }
};