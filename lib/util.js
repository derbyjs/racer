exports.onServer = typeof window === 'undefined';
exports.publicPath = function(name) {
  return !/(^_)|(\._)/.test(name);
};