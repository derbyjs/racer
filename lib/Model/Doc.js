module.exports = Doc;

function Doc(collectionName, id) {
  this.collectionName = collectionName;
  this.id = id;
}

Doc.prototype.path = function(segments) {
  return this.collectionName + '.' + this.id + '.' + segments.join('.');
};

Doc.prototype._get = function(snapshot, segments) {
  if (!segments) return snapshot;
  var node = snapshot;
  var i = 0;
  var key = segments[i++];
  while (key != null) {
    if (node == null) return;
    node = node[key];
    key = segments[i++];
  }
  return node;
};

Doc.prototype._errorMessage = function(description, segments, value) {
  return description + ' at ' + this.path(segments) + ': ' +
    JSON.stringify(value, null, 2);
};
