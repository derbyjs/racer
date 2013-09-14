var uuid = require('node-uuid');

Model.INITS = [];

module.exports = Model;

function Model(store, options) {
  this.store = store;
  var inits = Model.INITS;
  options || (options = {});
  for (var i = 0; i < inits.length; i++) {
    inits[i](this, options);
  }
}

Model.prototype.id = function() {
  return uuid.v4();
};
