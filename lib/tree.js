var joinPaths = require('./path').join;

exports.lookup = lookup;

function traverse (tree, path, iter) {
  var props = path.split('.')
    , curr = tree
    , currPath = ''
    , prop
    , next
    , parent
    ;
  while (prop = props.shift()) {
    currPath = currPath ? currPath + '.' + prop : prop;
    parent = curr;
    curr = curr[prop];

    // parts can be modified by iter(...)
    next = iter(curr, currPath, props, parent);
    currPath = next.path;
    curr = next.node;
    if (next.halt || curr == null) break;
  }
  return {
    node: curr
  , path: joinPaths(currPath, props)
  };
}

function lookup (tree, path, meta, eventEmitter) {
  var getRef = meta && meta.getRef
    , skipLast = meta && meta.skipLast
    , prevRests = meta && meta.prevRests
    ;
  if (skipLast && path.indexOf('.') === -1) {
    return {
      node: tree
    , path: ''
    };
  }
  return traverse(tree, path, function (node, pathToNode, rest, parent) {
    if (! node) {
      return {node: node, path: pathToNode, halt: true};
    }

    if (skipLast && rest.length === 1) var halt = true;

    if (typeof node === 'function') {
      if (getRef && ! rest.length) {
        var out = {node: node, path: pathToNode};
        if (halt) out.halt = true;
        return out;
      }
      var out = node(tree, pathToNode, rest, eventEmitter, prevRests);

      if (halt) out.halt = true;
      return out;
    }

    var out = {node: node, path: pathToNode};
    if (halt) out.halt = true;
    return out;
  });
}
