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
    return {
      data: this._data,
      base: this._base,
      clientId: this._clientId,
      txnCount: this._txnCount
    };
  },
  js: function() {
    return "(function() {\n  var model = rally.model;\n  model._data = " + (JSON.stringify(this._data)) + ";\n  model._base = " + (JSON.stringify(this._base)) + ";\n  model._clientId = " + (JSON.stringify(this._clientId)) + ";\n  model._txnCount = " + (JSON.stringify(this._txnCount)) + ";\n})();";
  }
};