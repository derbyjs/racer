var fs = require('fs')
  , tags = [];

require.extensions['.js'] = function (module, filename) {
  var content = fs.readFileSync(filename, 'utf8')
    , re = (tags.length)
         ? new RegExp("// *debug(" + tags.join('|') + "): *", 'gm')
         : /\/\/ *debug: */gm;
  content = content.replace(re, '');
  module._compile(content, filename);
};

module.exports = function () {
  var newTags = Array.prototype.slice.call(arguments, 0);
  tags = tags.concat(newTags);
};
