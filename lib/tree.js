exports.lookup = lookup;

function lookup (data, path, meta) {
  meta || (meta = {});

  if (meta.skipLast && path.indexOf('.') === -1) {
    return {node: data.world, path: ''};
  }

  var props = ( data.splits[path] || (data.splits[path] = path.split('.')) ).slice()
    , curr = data.world
    , currPath = ''
    , prop, halt

  while (prop = props.shift()) {
    currPath = currPath ? currPath + '.' + prop : prop;
    curr = curr[prop];

    // parts can be modified by iter(...)
    if (!curr) break;

    if (meta.skipLast && props.length === 1) halt = true;

    if (typeof curr === 'function' && !(meta.getRef && !props.length)) {
      // Note that props may be mutated
      var out = curr(data, currPath, props, meta);
      curr = out.node;
      currPath = out.path;
      if (halt || curr == null) break;
      continue;
    }

    if (halt || curr == null) break;
  }
  while (prop = props.shift()) {
    currPath = currPath ? currPath + '.' + prop : prop;
  }

  return {node: curr, path: currPath};
}
