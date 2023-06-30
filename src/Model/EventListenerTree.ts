var FastMap = require('./FastMap');

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
EventListenerTree.prototype.destroy = function() {
  // For all non-root nodes, remove the reference to the node
  var parent = this.parent;
  if (parent) {
    // Remove reference to this node from its parent
    var children = parent.children;
    if (children) {
      children.del(this.segment);
      if (children.size > 0) return;
      parent.children = null;
    }
    // Destroy parent if it no longer has any dependents
    if (!parent.listeners) {
      parent.destroy();
    }
    return;
  }
  // For the root node, reset any references to listeners or children
  this.children = null;
  this.listeners = null;
};

/**
 * Get a node for a path if it exists
 *
 * @param  {string[]} segments
 * @return {EventListenerTree|undefined}
 */
EventListenerTree.prototype._getChild = function(segments) {
  var node = this;
  for (var i = 0, len = segments.length; i < len; i++) {
    var children = node.children;
    if (!children) return;
    var segment = segments[i];
    node = children.values[segment];
    if (!node) return;
  }
  return node;
};

/**
 * If a path already has a node, return it. Otherwise, create the node and
 * ancestors in a lazy manner. Return the node for the path
 *
 * @param  {string[]} segments
 * @return {EventListenerTree}
 */
EventListenerTree.prototype._getOrCreateChild = function(segments) {
  var node = this;
  for (var i = 0, len = segments.length; i < len; i++) {
    var children = node.children;
    if (!children) {
      children = node.children = new FastMap();
    }
    var segment = segments[i];
    var next = children.values[segment];
    if (next) {
      node = next;
    } else {
      node = new EventListenerTree(node, segment);
      children.set(segment, node);
    }
  }
  return node;
};

/**
 * Add a listener to a path location. Listener should be unique per path
 * location, and calling twice with the same segments and listener value has no
 * effect. Unlike EventEmitter, listener may be any type of value
 *
 * @param  {string[]} segments
 * @param  {*} listener
 * @return {EventListenerTree}
 */
EventListenerTree.prototype.addListener = function(segments, listener) {
  var node = this._getOrCreateChild(segments);
  var listeners = node.listeners;
  if (listeners) {
    var i = listeners.indexOf(listener);
    if (i === -1) {
      listeners.push(listener);
    }
  } else {
    node.listeners = [listener];
  }
  return node;
};

/**
 * Remove a listener from a path location
 *
 * @param {string[]} segments
 * @param {*} listener
 */
EventListenerTree.prototype.removeListener = function(segments, listener) {
  var node = this._getChild(segments);
  if (node) {
    node.removeOwnListener(listener);
  }
};

/**
 * Remove a listener from the current node
 *
 * @param {*} listener
 */
EventListenerTree.prototype.removeOwnListener = function(listener) {
  var listeners = this.listeners;
  if (!listeners) return;
  if (listeners.length === 1) {
    if (listeners[0] === listener) {
      this.listeners = null;
      if (!this.children) {
        this.destroy();
      }
    }
    return;
  }
  var i = listeners.indexOf(listener);
  if (i > -1) {
    listeners.splice(i, 1);
  }
};

/**
 * Remove all listeners and descendent listeners for a path location
 *
 * @param {string[]} segments
 */
EventListenerTree.prototype.removeAllListeners = function(segments) {
  var node = this._getChild(segments);
  if (node) {
    node.destroy();
  }
};

/**
 * Return direct listeners to `segments`
 *
 * @param  {string[]} segments
 * @return {Array} listeners
 */
EventListenerTree.prototype.getListeners = function(segments) {
  var node = this._getChild(segments);
  return (node && node.listeners) ? node.listeners.slice() : [];
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
EventListenerTree.prototype.getAffectedListeners = function(segments) {
  var listeners = [];
  var node = pushAncestorListeners(listeners, segments, this);
  if (node) {
    pushDescendantListeners(listeners, node);
  }
  return listeners;
};

/**
 * Return an array with each of the listeners to descendent nodes, not
 * including listeners to `segments` itself
 *
 * @param  {string[]} segments
 * @return {Array} listeners
 */
EventListenerTree.prototype.getDescendantListeners = function(segments) {
  var listeners = [];
  var node = this._getChild(segments);
  if (node) {
    pushDescendantListeners(listeners, node);
  }
  return listeners;
};

/**
 * Return an array with each of the listeners to descendent nodes, not
 * including listeners to this node itself
 *
 * @return {Array} listeners
 */
EventListenerTree.prototype.getOwnDescendantListeners = function() {
  var listeners = [];
  pushDescendantListeners(listeners, this);
  return listeners;
};

/**
 * Return an array with each of the listeners to `segments`, including
 * treating wildcard segments ('*') and remainder segments ('**') as matches
 *
 * @param  {string[]} segments
 * @return {Array} listeners
 */
EventListenerTree.prototype.getWildcardListeners = function(segments) {
  var listeners = [];
  pushWildcardListeners(listeners, this, segments, 0);
  return listeners;
};

/**
 * Push listeners matching `segments`, wildcards ('*'), and remainders ('**')
 * onto passed in array. Start from segments index passed in for branching
 * recursion without needing to modify segments array
 *
 * @param {Array} listeners
 * @param {EventListenerTree} node
 * @param {string[]} segments
 * @param {integer} start
 */
function pushWildcardListeners(listeners, node, segments, start) {
  for (var i = start, len = segments.length; i < len; i++) {
    var children = node.children;
    if (!children) return;
    pushRemainderListeners(listeners, node);
    var wildcardNode = children.values['*'];
    if (wildcardNode) {
      pushWildcardListeners(listeners, wildcardNode, segments, i + 1);
    }
    var segment = segments[i];
    node = children.values[segment];
    if (!node) return;
  }
  if (node.children) {
    pushRemainderListeners(listeners, node);
  }
  pushListeners(listeners, node);
};

/**
 * Push listeners to the '**' onto the passed in array
 *
 * @param {Array} listeners
 * @param {EventListenerTree} node
 */
function pushRemainderListeners(listeners, node) {
  var remainderNode = node.children.values['**'];
  if (remainderNode) {
    pushListeners(listeners, remainderNode);
  }
}

/**
 * Push direct listeners onto the passed in array
 *
 * @param {Array} listeners
 * @param {EventListenerTree} node
 */
function pushListeners(listeners, node) {
  var nodeListeners = node.listeners;
  if (!nodeListeners) return;
  for (var i = 0, len = nodeListeners.length; i < len; i++) {
    listeners.push(nodeListeners[i]);
  }
}

/**
 * Push listeners for each ancestor node and the node at `segments` onto the
 * passed in array. Return the node at `segments` if it exists
 *
 * @param  {Array} listeners
 * @param  {string[]} segments
 * @param  {EventListenerTree} node
 * @return {EventListenerTree|undefined}
 */
function pushAncestorListeners(listeners, segments, node) {
  pushListeners(listeners, node);
  for (var i = 0, len = segments.length; i < len; i++) {
    var children = node.children;
    if (!children) return;
    var segment = segments[i];
    node = children.values[segment];
    if (!node) return;
    pushListeners(listeners, node);
  }
  return node;
}

/**
 * Push listeners for each of the node's children and their recursive children
 * onto the passed in array
 *
 * @param {Array} listeners
 * @param {EventListenerTree} node
 */
function pushDescendantListeners(listeners, node) {
  if (!node.children) return;
  var values = node.children.values;
  for (var key in values) {
    var child = values[key];
    pushListeners(listeners, child);
    pushDescendantListeners(listeners, child);
  }
}
