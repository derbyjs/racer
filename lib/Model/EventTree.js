module.exports = EventTree;

function EventTree(parent, segment) {
  this.parent = parent;
  this.segment = segment;
  this.children = null;
  this.listeners = null;
}

EventTree.prototype.destroy = function() {
  // Ignore calls to destroy a root node
  if (!this.parent) return;

  // Remove reference this node from its parent
  if (hasOtherKeys(this.parent.children, this.segment)) {
    delete this.parent.children[this.segment];
    return;
  }
  this.parent.children = null;

  // Destroy parent if it no longer has any dependents
  if (!this.parent.listeners) {
    this.parent.destroy();
  }
};

EventTree.prototype.getChild = function(segments) {
  var node = this;
  for (var i = 0; i < segments.length; i++) {
    var segment = segments[i];
    node = node.children && node.children[segment];
    if (!node) return;
  }
  return node;
};

EventTree.prototype.getOrCreateChild = function(segments) {
  var node = this;
  for (var i = 0; i < segments.length; i++) {
    var segment = segments[i];
    if (!node.children) {
      node.children = {};
    }
    var node = node.children[segment] ||
      (node.children[segment] = new EventTree(node, segment));
  }
  return node;
};

EventTree.prototype.addListener = function(segments, listener) {
  var node = this.getOrCreateChild(segments);
  if (!node.listeners) {
    node.listeners = [listener];
    return;
  }
  var i = node.listeners.indexOf(listener);
  if (i === -1) {
    node.listeners.push(listener);
  }
};

EventTree.prototype.removeListener = function(segments, listener) {
  var node = this.getChild(segments);
  if (!node || !node.listeners) return;
  if (node.listeners.length === 1) {
    if (node.listeners[0] === listener) {
      node.listeners = null;
      if (!node.children) {
        node.destroy();
      }
    }
    return;
  }
  var i = node.listeners.indexOf(listener);
  if (i > -1) {
    node.listeners.splice(i, 1);
  }
};

EventTree.prototype.forListeners = function(callback) {
  if (!this.listeners) return;
  for (var i = 0; i < this.listeners.length; i++) {
    var listener = this.listeners[i];
    callback(listener);
  }
};

EventTree.prototype.forEach = function(segments, callback) {
  var node = this;
  node.forListeners(callback);
  for (var i = 0; i < segments.length; i++) {
    var segment = segments[i];
    node = node.children && node.children[segment];
    if (!node) return;
    node.forListeners(callback);
  }
  forDescendents(node, callback);
};

function forDescendents(node, callback) {
  if (!node.children) return;
  for (var key in node.children) {
    var child = node.children[key];
    child.forListeners(callback);
    forDescendents(child, callback);
  }
}

function hasOtherKeys(object, ignore) {
  for (var key in object) {
    if (key !== ignore) return true;
  }
  return false;
}
