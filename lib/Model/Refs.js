module.exports = Refs;

function Ref(from, to) {
  this.from = from;
  this.to = to;
  this.fromSegments = from.split('.');
}

function FromMap() {}
function ToMap() {}

function Refs() {
  this.fromMap = new FromMap;
  this.toMap = new ToMap;
}

Refs.prototype.add = function(from, to) {
  var ref = new Ref(from, to);
  this.fromMap[from] = ref;
  this.toMap[to] = ref;
};

Refs.prototype.remove = function(from) {
  var ref = this.fromMap[from];
  if (!ref) return;
  delete this.fromMap[from];
  delete this.toMap[ref.to];
};
