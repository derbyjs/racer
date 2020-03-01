var Model = require('./Model');
var Query = require('./Query');

/*
 * Just return Promise which rejected on cb-error and resolved with function return
 */
function promisify(func, argumentsObject) {
  var args = Array.prototype.slice.call(argumentsObject);
  var self = this;

  return new Promise(function(resolve, reject) {
    var result;
    args.push(function(err) {
      if (err) reject(err);
      else resolve(result);
    });

    result = func.apply(self, args);
  });
}

// For model

Model.prototype.fetchAsync = function() {
  return promisify(this.fetch.bind(this), arguments);
};

Model.prototype.unfetchAsync = function() {
  return promisify(this.unfetch.bind(this), arguments);
};

Model.prototype.subscribeAsync = function() {
  return promisify(this.subscribe.bind(this), arguments);
};

Model.prototype.unsubscribeAsync = function() {
  return promisify(this.unsubscribe.bind(this), arguments);
};

Model.prototype.setAsync = function() {
  return promisify(this.set.bind(this), arguments);
};

Model.prototype.setDiffAsync = function() {
  return promisify(this.setDiff.bind(this), arguments);
};

Model.prototype.setDiffDeepAsync = function() {
  return promisify(this.setDiffDeep.bind(this), arguments);
};

Model.prototype.setNullAsync = function() {
  return promisify(this.setNull.bind(this), arguments);
};

Model.prototype.setEachAsync = function() {
  return promisify(this.setEach.bind(this), arguments);
};

Model.prototype.createAsync = function() {
  return promisify(this.create.bind(this), arguments);
};

Model.prototype.createNullAsync = function() {
  return promisify(this.createNull.bind(this), arguments);
};

Model.prototype.addAsync = function() {
  return promisify(this.add.bind(this), arguments);
};

Model.prototype.delAsync = function() {
  return promisify(this.del.bind(this), arguments);
};

Model.prototype.incrementAsync = function() {
  return promisify(this.increment.bind(this), arguments);
};

Model.prototype.pushAsync = function() {
  return promisify(this.push.bind(this), arguments);
};

Model.prototype.unshiftAsync = function() {
  return promisify(this.unshift.bind(this), arguments);
};

Model.prototype.insertAsync = function() {
  return promisify(this.insert.bind(this), arguments);
};

Model.prototype.popAsync = function() {
  return promisify(this.pop.bind(this), arguments);
};

Model.prototype.shiftAsync = function() {
  return promisify(this.shift.bind(this), arguments);
};

Model.prototype.removeAsync = function() {
  return promisify(this.remove.bind(this), arguments);
};

Model.prototype.moveAsync = function() {
  return promisify(this.move.bind(this), arguments);
};

Model.prototype.stringInsertAsync = function() {
  return promisify(this.stringInsert.bind(this), arguments);
};

Model.prototype.stringRemoveAsync = function() {
  return promisify(this.stringRemove.bind(this), arguments);
};

// For queries

Query.prototype.fetchAsync = function() {
  return promisify(this.fetch.bind(this), arguments);
};

Query.prototype.unfetchAsync = function() {
  return promisify(this.unfetch.bind(this), arguments);
};

Query.prototype.subscribeAsync = function() {
  return promisify(this.subscribe.bind(this), arguments);
};

Query.prototype.unsubscribeAsync = function() {
  return promisify(this.unsubscribe.bind(this), arguments);
};
