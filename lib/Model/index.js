var uuid = require('node-uuid');
var racer = require('../racer');

module.exports = Model;

require('./events');
require('./scoped');

function Model() {
  this.flags || (this.flags = {});

  racer.emit('Model:init', this);
}

Model.prototype.id = function() {
  return uuid.v4();
};
