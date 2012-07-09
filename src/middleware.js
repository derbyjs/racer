module.exports = function () {
  var mware = {};
  return {
    add: function (channel, fn) {
      var fns = mware[channel] || (mware[channel] = []);
      fns.push(fn);
    }
  , trigger: function (channel, req, res) {
      var fns = mware[channel];
      if (!fns.length) return;
      var i = 0
        , out;
      function next () {
        var fn = fns[i++];
        return fn ? (out = fn(req, res, next))
                  : out;
      }
      return next();
    }
  };
}
