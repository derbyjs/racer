exports.publicPath = function(name) {
  return !/(^_)|(\._)/.test(name);
};