var Store = require('./Store');
var Racer = require('./Racer');

Racer.prototype.Store = Store;
Racer.prototype.version = require('../package').version;

Racer.prototype.createStore = function(options) {
  var store = new Store(this, options);
  this.emit('store', store);
  return store;
};
