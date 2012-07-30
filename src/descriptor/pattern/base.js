module.exports = {
  name: 'Pattern'
, normalize: function (x) { return x._at || x; }
, isInstance: function (x) { return typeof x === 'string' || x._at; }
, registerFetch: function () {}
};
