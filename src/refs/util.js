module.exports = {
  derefPath: function (data, to) {
    return data.$deref ? data.$deref() : to;
  }

, lookupPath: function (path, props, i) {
    return [path].concat(props.slice(i, props.length)).join('.');
  }
};
