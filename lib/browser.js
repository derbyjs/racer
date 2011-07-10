var model;
this.model = model = new (require('./Model'));
this.init = function(_arg) {
  var base, clientId, data, ioUri, txnCount;
  data = _arg.data, base = _arg.base, clientId = _arg.clientId, txnCount = _arg.txnCount, ioUri = _arg.ioUri;
  model._data = data;
  model._base = base;
  model._clientId = clientId;
  model._txnCount = txnCount;
  model._setSocket(io.connect(ioUri));
  return this;
};