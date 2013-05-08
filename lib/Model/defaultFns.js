var util = require('../util');
var Model = require('./index');

function getSort(array, comparator) {
  return array && array.slice().sort(comparator);
}
function setSort(values, array) {
  // TODO
}
Model.fn('sort', {get: getSort, set: setSort});

function getReverse(array) {
  return array && array.slice().reverse();
}
function setReverse(values) {
  return {0: getReverse(values)};
}
Model.fn('reverse', {get: getReverse, set: setReverse});

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
Model.fn('filter', {get: getFilter, set: setFilter});

function getMap(array, fn) {

}
function setMap(values, array, fn) {

}
Model.fn('map', {get: getMap, set: setMap});

function getMapIds(to, ids) {
  if (!to || !ids) return;
  var values = [];
  for (var i = 0, len = ids.length; i < len; i++) {
    var value = to[ids[i]];
    values.push(value);
  }
  return values;
}
function setMapIds(values, to, ids) {
  if (!values || !to || typeof to !== 'object') return;
  to = util.copyObject(to);
  ids = [];
  for (var i = 0, len = values.length; i < len; i++) {
    var value = values[i];
    var id = util.keyOf(to, value);
    if (id == null) {
      // `this` is the root model instance
      id = (value && value.id) || this.id();
    }
    to[id] = value;
    ids.push(id);
  }
  // Using each will add and update object properties, but not delete them
  return {each: {0: to}, 1: ids};
}
Model.fn('mapIds', {get: getMapIds, set: setMapIds});
