exports.onServer = typeof window === 'undefined';

exports.publicPath = function(name) {
  // Test to see if path name contains a segment that starts with an underscore.
  // Such a path is private to the current session and should not be stored
  // in persistent storage or synced with other clients.
  return ! /(^_)|(\._)/.test(name);
}