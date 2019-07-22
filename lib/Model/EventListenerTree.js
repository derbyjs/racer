module.exports = EventListenerTree;

/**
 * Construct a tree root when invoked without any arguments. Children nodes are
 * constructred internally as needed on calls to addListener()
 *
 * @param {EventListenerTree} [parent]
 * @param {string} [segment]
 */
function EventListenerTree(parent, segment) {
  this.parent = parent;
  this.segment = segment;
  this.children = null;
  this.listeners = null;
}

/**
 * Remove the reference to this node from its parent so that it can be garbage
 * collected. This is called internally when all listeners to a node
 * are removed
 */
EventListenerTree.prototype._destroy = function() {
  // For all non-root nodes, remove the reference to the node
  if (this.parent) {
    removeChild(this.parent, this.segment);
  // For the root node, reset any references to listeners or children
  } else {
    this.children = null;
    this.listeners = null;
  }
};

/**
 * Get a node for a path if it exists
 *
 * @param  {string[]} segments
 * @return {EventListenerTree|undefined}
 */
EventListenerTree.prototype._getChild = function(segments) {
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
 * @return {EventListenerTree}
 */
EventListenerTree.prototype._getOrCreateChild = function(segments) {
  var node = this;
  for (var i = 0; i < segments.length; i++) {
    var segment = segments[i];
    if (!node.children) {
      node.children = {};
    }
    var node = node.children[segment] ||
      (node.children[segment] = new EventListenerTree(node, segment));
  }
  return node;
};

/**
 * Add a listener to a path location. Listener should be unique per path
 * location, and calling twice witht the same segments and listener value has no
 * effect. Unlike EventEmitter, listener may be any type of value. The value is
 * returned to a callback upon calling `forEachAffected`.
 *
 * @param {string[]} segments
 * @param {*} listener
 */
EventListenerTree.prototype.addListener = function(segments, listener) {
  var node = this._getOrCreateChild(segments);
  if (!node.listeners) {
    node.listeners = [listener];
    return;
  }
  var i = node.listeners.indexOf(listener);
  if (i === -1) {
    node.listeners.push(listener);
  }
};

/**
 * Remove a listener from a path location.
 *
 * @param {string[]} segments
 * @param {*} listener
 */
EventListenerTree.prototype.removeListener = function(segments, listener) {
  var node = this._getChild(segments);
  if (!node || !node.listeners) return;
  if (node.listeners.length === 1) {
    if (node.listeners[0] === listener) {
      node.listeners = null;
      if (!node.children) {
        node._destroy();
      }
    }
    return;
  }
  var i = node.listeners.indexOf(listener);
  if (i > -1) {
    node.listeners.splice(i, 1);
  }
};

/**
 * Remove all listeners and descendent listeners for a path location.
 *
 * @param {string[]} segments
 */
EventListenerTree.prototype.removeAllListeners = function(segments) {
  var node = this._getChild(segments);
  if (node) {
    node._destroy();
  }
};

/**
 * Dispatch an event to each of the listeners that may be affected by a change
 * to a model path. These are:
 *   1. Listeners to each node from the root to the node for `segments`
 *   2. Listeners to all descendent nodes under `segments`
 *
 * Calls the callback with each listener value, conceptually similar to
 * Array#forEach()
 *
 * @param {string[]} segments
 * @param {Function} callback
 */
EventListenerTree.prototype.forEachAffected = function(segments, callback) {
  var node = forAncestorListeners(this, segments, callback);
  if (node) {
    forDescendantListeners(node, callback);
  }
};

/**
 * Call the callback with each listener value in the current node.
 *
 * @param {EventListenerTree} node
 * @param {Function} callback
 */
function forListeners(node, callback) {
  if (!node.listeners) return;
  for (var i = 0; i < node.listeners.length; i++) {
    var listener = node.listeners[i];
    callback(listener);
  }
}

/**
 * Call the callback with each listener value from the root node passed in to
 * the node for `segments`. Return the node at `segments` if it exists
 *
 * @param  {EventListenerTree} node
 * @param  {string[]} segments
 * @param  {Function} callback
 * @return {EventListenerTree|undefined}
 */
function forAncestorListeners(node, segments, callback) {
  forListeners(node, callback);
  for (var i = 0; i < segments.length; i++) {
    var segment = segments[i];
    node = node.children && node.children[segment];
    if (!node) return;
    forListeners(node, callback);
  }
  return node;
}

/**
 * Call the callback with each listener value for each of the node's children
 * and their recursive children
 *
 * @param {EventListenerTree} node
 * @param {Function} callback
 */
function forDescendantListeners(node, callback) {
  if (!node.children) return;
  for (var key in node.children) {
    var child = node.children[key];
    forListeners(child, callback);
    forDescendantListeners(child, callback);
  }
}

/**
 * Remove the child at the specified segment from a node. Also recursively
 * remove parent nodes if there are no remaining dependencies
 *
 * @param {EventListenerTree} node
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
  if (!node.listeners) {
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
