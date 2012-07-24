var Stream = require('stream').Stream
  ;

module.exports = function sortStream (sortFn) {
  var stream = new Stream();

  stream.writable = true;
  stream.readable = true;

  var ended = false;

  stream.write = function () {
    if (ended) throw new Error('Sort stream is not writeable');
  };
};
