var lookup = require('../path').lookup
  , specIdentifier = require('../util/speculative').identifier

module.exports = {
  sortDomain: sortDomain
, deriveComparator: deriveComparator
};

function sortDomain (domain, comparator) {
  if (! Array.isArray(domain)) {
    var list = [];
    for (var k in domain) {
      if (k === specIdentifier) continue;
      list.push(domain[k]);
    }
    domain = list;
  }
  if (!comparator) return domain;
  return domain.sort(comparator);
}

// TODO Do the functions below need to belong here?

/**
 * Generates a comparator function that returns -1, 0, or 1
 * if a < b, a == b, or a > b respectively, according to the ordering criteria
 * defined by sortParams
 * , e.g., sortParams = ['field1', 'asc', 'field2', 'desc']
 */
function deriveComparator (sortList) {
  return function comparator (a, b, sortParams) {
    sortParams || (sortParams = sortList);
    var dir, path, factor, aVal, bVal
      , aIsIncomparable, bIsIncomparable;
    for (var i = 0, l = sortParams.length; i < l; i+=2) {
      var dir = sortParams[i+1];
      switch (dir) {
        case 'asc' : factor =  1; break;
        case 'desc': factor = -1; break;
        default: throw new Error('Must be "asc" or "desc"');
      }
      path = sortParams[i];
      aVal = lookup(path, a);
      bVal = lookup(path, b);

      // Handle undefined, null, or in-comparable aVal and/or bVal.
      aIsIncomparable = isIncomparable(aVal)
      bIsIncomparable = isIncomparable(bVal);

      // Incomparables always come last.
      if ( aIsIncomparable && !bIsIncomparable) return factor;
      // Incomparables always come last, even in reverse order.
      if (!aIsIncomparable &&  bIsIncomparable) return -factor;

      // Tie-break 2 incomparable fields by comparing more downstream ones
      if ( aIsIncomparable &&  bIsIncomparable) continue;

      // Handle comparable field values
      if      (aVal < bVal) return -factor;
      else if (aVal > bVal) return factor;

      // Otherwise, the field values for both docs so far are equivalent
    }
    return 0;
  };
}

function isIncomparable (x) {
  return (typeof x === 'undefined') || x === null;
}

