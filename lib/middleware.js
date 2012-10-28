module.exports = function () {
  var fns = [];
  function run (req, res, done) {
    var i = 0, out;
    function next () {
      var fn = fns[i++];
      return fn ? (out = fn(req, res, next))
                : done ? done() : out;
    }
    return next();
  }

  run.add = function (fn) {
    fns.push(fn);
    return this;
  };

  return run;
};
