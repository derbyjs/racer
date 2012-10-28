module.exports = {
  normArgs: normArgs
};

function normArgs (_arguments_) {
  var arglen = _arguments_.length
    , lastArg = _arguments_[arglen-1]
    , cb = (typeof lastArg === 'function') ? lastArg : noop
    , descriptors = Array.prototype.slice.call(_arguments_, 0, cb ? arglen-1 : arglen);
  return [descriptors, cb];
}

