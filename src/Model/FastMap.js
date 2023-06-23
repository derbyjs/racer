module.exports = FastMap;

function FastMap() {
  this.values = {};
  this.size = 0;
}
FastMap.prototype.set = function(key, value) {
  if (!(key in this.values)) {
    this.size++;
  }
  return this.values[key] = value;
};
FastMap.prototype.del = function(key) {
  if (key in this.values) {
    this.size--;
  }
  delete this.values[key];
};
