module.exports = EventMapTree;

/**
 * Construct a tree root when invoked without any arguments. Children nodes are
 * constructred internally as needed on calls to addListener()
 *
 * @param {EventMapTree} [parent]
 * @param {string} [segment]
 */
function EventMapTree(parent, segment) {
  this.parent = parent;
  this.segment = segment;
  this.children = null;
  this.listener = null;
}

/**
 * Remove the reference to this node from its parent so that it can be garbage
 * collected. This is called internally when all listener to a node
 * are removed
 */
EventMapTree.prototype._destroy = function() {
  // For all non-root nodes, remove the reference to the node
  if (this.parent) {
    removeChild(this.parent, this.segment);
  // For the root node, reset any references to listener or children
  } else {
    this.children = null;
    this.listener = null;
  }
};

/**
 * Get a node for a path if it exists
 *
 * @param  {string[]} segments
 * @return {EventMapTree|undefined}
 */
EventMapTree.prototype._getChild = function(segments) {
  var node = this;
  for (var i = 0; i < segments.length; i++) {
    var segment = segments[i];
    node = node.children && node.children[segment];
    if (!node) return;
  }
  return node;
};

/**
 * If a path already has a node, return it. Otherwise, create the node and
 * parents in a lazy manner and return the node for the path
 *
 * @param  {string[]} segments
 * @return {EventMapTree}
 */
EventMapTree.prototype._getOrCreateChild = function(segments) {
  var node = this;
  for (var i = 0; i < segments.length; i++) {
    var segment = segments[i];
    if (!node.children) {
      node.children = {};
    }
    var node = node.children[segment] ||
      (node.children[segment] = new EventMapTree(node, segment));
  }
  return node;
};

/**
 * Assign a listener to a path location. Listener may be any type of value.
 * Return the previous listener value if any
 *
 * @param {string[]} segments
 * @param {*} listener
 */
EventMapTree.prototype.setListener = function(segments, listener) {
  var node = this._getOrCreateChild(segments);
  var previous = node.listener;
  node.listener = listener;
  return previous;
};

/**
 * Remove the listener at a path location and return it
 *
 * @param  {string[]} segments
 * @return {*} listener
 */
EventMapTree.prototype.deleteListener = function(segments) {
  var node = this._getChild(segments);
  if (!node) return;
  var previous = node.listener;
  node.listener = null;
  if (!node.children) {
    node._destroy();
  }
  return previous;
};

/**
 * Remove all listeners and descendent listeners for a path location
 *
 * @param {string[]} segments
 */
EventMapTree.prototype.deleteAllListeners = function(segments) {
  var node = this._getChild(segments);
  if (node) {
    node._destroy();
  }
};

/**
 * Return the direct listener to `segments` if any
 *
 * @param  {string[]} segments
 * @return {*} listeners
 */
EventMapTree.prototype.getListener = function(segments) {
  var node = this._getChild(segments);
  return (node) ? node.listener : null;
};

/**
 * Return an array with each of the listeners that may be affected by a change
 * to `segments`. These are:
 *   1. Listeners to each node from the root to the node for `segments`
 *   2. Listeners to all descendent nodes under `segments`
 *
 * @param  {string[]} segments
 * @return {Array} listeners
 */
EventMapTree.prototype.getAffectedListeners = function(segments) {
  var listeners = [];
  var node = pushAncestorListeners(listeners, segments, this);
  if (node) {
    pushDescendantListeners(listeners, node);
  }
  return listeners;
};

/**
 * Return an array with each of the listeners to `segments` and descendent nodes
 *
 * @param  {string[]} segments
 * @return {Array} listeners
 */
EventMapTree.prototype.getAllListeners = function(segments) {
  var listeners = [];
  var node = this._getChild(segments);
  if (node) {
    pushListener(listeners, node);
    pushDescendantListeners(listeners, node);
  }
  return listeners;
};

/**
 * Push node's direct listener onto the passed in array if not null
 *
 * @param {Array} listeners
 * @param {EventMapTree} node
 */
function pushListener(listeners, node) {
  if (node.listener != null) {
    listeners.push(node.listener);
  }
}

/**
 * Push listeners for each ancestor node and the node at `segments` onto the
 * passed in array. Return the node at `segments` if it exists
 *
 * @param  {Array} listeners
 * @param  {string[]} segments
 * @param  {EventMapTree} node
 * @return {EventMapTree|undefined}
 */
function pushAncestorListeners(listeners, segments, node) {
  pushListener(listeners, node);
  for (var i = 0; i < segments.length; i++) {
    var segment = segments[i];
    node = node.children && node.children[segment];
    if (!node) return;
    pushListener(listeners, node);
  }
  return node;
}

/**
 * Push listeners for each of the node's children and their recursive children
 * onto the passed in array
 *
 * @param {Array} listeners
 * @param {EventMapTree} node
 */
function pushDescendantListeners(listeners, node) {
  if (!node.children) return;
  for (var key in node.children) {
    var child = node.children[key];
    pushListener(listeners, child);
    pushDescendantListeners(listeners, child);
  }
}

/**
 * Call the callback with each listener to the node and its decendants
 *
 * @param {EventMapTree} node
 * @param {Function} callback
 */
EventMapTree.prototype.forEach = function(callback) {
  forListener(this, callback);
  forDescendantListeners(this, callback);
};

/**
 * Call the callback with the node's direct listener if not null
 *
 * @param {EventMapTree} node
 * @param {Function} callback
 */
function forListener(node, callback) {
  if (node.listener != null) {
    callback(node.listener);
  }
}

/**
 * Call the callback with each listener value for each of the node's children
 * and their recursive children
 *
 * @param {EventMapTree} node
 * @param {Function} callback
 */
function forDescendantListeners(node, callback) {
  if (!node.children) return;
  for (var key in node.children) {
    var child = node.children[key];
    forListener(child, callback);
    forDescendantListeners(child, callback);
  }
}

/**
 * Remove the child at the specified segment from a node. Also recursively
 * remove parent nodes if there are no remaining dependencies
 *
 * @param {EventMapTree} node
 * @param {string} segment
 */
function removeChild(node, segment) {
  // Remove reference this node from its parent
  if (hasOtherKeys(node.children, segment)) {
    delete node.children[segment];
    return;
  }
  node.children = null;

  // Destroy parent if it no longer has any dependents
  if (node.listener == null) {
    node._destroy();
  }
}

/**
 * Return whether the object has any other property key other than the
 * provided value.
 *
 * @param  {Object} object
 * @param  {string} ignore
 * @return {Boolean}
 */
function hasOtherKeys(object, ignore) {
  for (var key in object) {
    if (key !== ignore) return true;
  }
  return false;
}

