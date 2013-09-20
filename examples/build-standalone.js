var fs = require('fs');
var path = require('path');
var bundle = require('../lib/bundle');

var bundleOptions = {
  minify: true
, configure: function(b) {
    b.require(__dirname + '/../lib/Model/standalone', {expose: 'Model'});
  }
}

bundle(bundleOptions, function(err, code, map) {
  if (err) throw err;
  fs.writeFile('racer-standalone.js', code);
});
