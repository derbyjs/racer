var defaultFns = module.exports = new DefaultFns;

defaultFns.sort = new FnPair(getSort, setSort);
defaultFns.reverse = new FnPair(getReverse, setReverse);
defaultFns.filter = new FnPair(getFilter, setFilter);

function DefaultFns() {}
function FnPair(get, set) {
  this.get = get;
  this.set = set;
}

function getSort(array, comparator) {
  return array && array.slice().sort(comparator);
}
function setSort(values, array) {
  // TODO
}

function getReverse(array) {
  return array && array.slice().reverse();
}
function setReverse(values) {
  return {0: getReverse(values)};
}

function getFilter(array, fn) {
  return array && array.filter(fn, this);
}
function setFilter(values, array) {
  if (!values) return;
  for (var i = 0; i < values.length; i++) {
    var value = values[i];
    var index = array.indexOf(value);
  }
}
