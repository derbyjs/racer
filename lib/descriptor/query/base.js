module.exports = {
  name: 'Query'
, normalize: function (x) {
    return x.tuple ? x.tuple : x;
  }
, isInstance: function (x) { return Array.isArray(x) || x.tuple; }
};
