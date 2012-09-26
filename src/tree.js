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
    currPath += (currPath ? '.' + prop : prop);
    parent = curr;
    if (Array.isArray(curr)) {
      if (prop === 'length') {
        curr = curr.length;
      } else {
        prop = parseInt(prop, 10);
        curr = curr[prop];
      }
    } else {
      curr = curr[prop];
    }

    // parts can be modified by iter(...)
    next = iter(curr, currPath, props, parent);
    currPath = next.path;
    curr     = next.node;
    if (next.halt) break;
  }
  return {
    node: curr
  , path: joinPaths(currPath, props)
  };
}

function lookup (tree, path, meta, ee) {
  var getRef   = meta && meta.getRef
    , skipLast = meta && meta.skipLast
    , prevRest = meta && meta.prevRest
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
      var out = node(tree, pathToNode, rest, ee, prevRest);

      if (halt) out.halt = true;
      return out;
    }

    var out = {node: node, path: pathToNode};
    if (halt) out.halt = true;
    return out;
  });
}


//function lookup (obj, path) {
//  var dotPos = path.indexOf('.');
//  var leadingProp = path.slice(0, dotPos);
//  return lookup(obj[leadingProp], path.slice(dotPos + 1));
//}
