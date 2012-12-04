var isProduction = require('../util').isProduction

module.exports = {
  init: init
, bundledFunction: bundledFunction
, unbundledFunction: unbundledFunction
}

var racer;
function init (_racer) {
  racer = _racer;
};

function bundledFunction (fn) {
  var fnStr = fn.toString();
  if (isProduction) {
    // Uglify can't parse a naked function. Executing it allows Uglify to
    // parse it properly
    var minified = racer.get('minifyJs')('(' + fnStr + ')();');
    fnStr = minified.slice(1, -4);
  }
  return fnStr;
}

function unbundledFunction (fnStr) {
  return (new Function('return ' + fnStr + ';'))();
}
