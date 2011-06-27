// Based on Underscore.js:

var isArray = exports.isArray = Array.isArray || function(obj) {
  return toString.call(obj) === '[object Array]';
};
var isArguments = exports.isArguments = function(obj) {
  return !!(obj && hasOwnProperty.call(obj, 'callee'));
};
exports.isFunction = function(obj) {
  return !!(obj && obj.constructor && obj.call && obj.apply);
};
exports.isString = function(obj) {
  return !!(obj === '' || (obj && obj.charCodeAt && obj.substr));
};
exports.isNumber = function(obj) {
  return !!(obj === 0 || (obj && obj.toExponential && obj.toFixed));
};
// NaN happens to be the only value in JavaScript that does not equal itself.
exports.isNaN = function(obj) {
  return obj !== obj;
};
exports.isDate = function(obj) {
  return !!(obj && obj.getTimezoneOffset && obj.setUTCFullYear);
};
exports.isRegExp = function(obj) {
  return !!(obj && obj.test && obj.exec && (obj.ignoreCase || obj.ignoreCase === false));
};
// Safely convert anything iterable into a real, live array.
exports.toArray = function(iterable) {
  if (!iterable) return [];
  if (iterable.toArray) return iterable.toArray();
  if (isArguments(iterable)) return Array.slice.call(iterable);
  if (isArray(iterable)) return iterable;
  return forEach(iterable, function(key, value) { return value; });
};

// Custom utils:

exports.onServer = typeof window === 'undefined';

exports.publicPath = function(name) {
  // Test to see if path name contains a segment that starts with an underscore.
  // Such a path is private to the current session and should not be stored
  // in persistent storage or synced with other clients.
  return ! /(^_)|(\._)/.test(name);
}