
function FnPair(get, set) {
  this.get = get;
  this.set = set;
}

function getReverse(array) {
  return array && array.slice().reverse();
}

function setReverse(values) {
  return {0: getReverse(values)};
}

export const reverse = new FnPair(getReverse, setReverse);

export function asc(a, b) {
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

export function desc(a, b) {
  if (a > b) return -1;
  if (a < b) return 1;
  return 0;
}
