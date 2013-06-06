var util = require('../util');
var Model = require('./index');

Model.INITS.push(function(model) {
  model._filters = new Filters(model);
  model.on('all', filterListener);
  function filterListener(segments, eventArgs) {
    var pass = eventArgs[eventArgs.length - 1];
    var map = model._filters.fromMap;
    for (var path in map) {
      var filter = map[path];
      if (pass.$filter === filter) continue;
      if (util.mayImpact(filter.inputSegments, segments)) {
        filter.update(pass);
      }
    }
  }
});

Model.prototype.filter = function(input, fn) {
  if (typeof fn === 'string') {
    fn = this._namedFns[fn];
  }
  var inputPath = this.path(input);
  return this._filters.add(inputPath, fn);
};

Model.prototype.sort = function(input, fn) {
  if (!fn) fn = 'asc';
  if (typeof fn === 'string') {
    fn = this._namedFns[fn];
  }
  var inputPath = this.path(input);
  return this._filters.add(inputPath, null, fn);
};

function FromMap() {}
function Filters(model) {
  this.model = model;
  this.fromMap = new FromMap;
}
Filters.prototype.add = function(inputPath, filterFn, sortFn) {
  return new Filter(this, inputPath, filterFn, sortFn);
};

function Filter(filters, inputPath, filterFn, sortFn) {
  this.filters = filters;
  this.model = filters.model.pass({$filter: this});
  this.inputPath = inputPath;
  this.filterFn = filterFn;
  this.sortFn = sortFn;
  this.inputSegments = inputPath.split('.');
  this.idsSegments = null;
  this.from = null;
}
Filter.prototype.sort = function(fn) {
  if (!fn) fn = 'asc';
  if (typeof fn === 'string') {
    fn = this.model._namedFns[fn];
  }
  this.sortFn = fn;
  return this;
};
Filter.prototype.ids = function() {
  var items = this.model._get(this.inputSegments);
  var ids = [];
  if (Array.isArray(items)) {
    if (this.filterFn) {
      for (var i = 0; i < items.length; i++) {
        if (this.filterFn.call(this.model, items[i], i, items)) {
          ids.push(i);
        }
      }
    } else {
      for (var i = 0; i < items.length; i++) ids.push(i);
    }
  } else {
    if (this.filterFn) {
      for (var key in items) {
        if (items.hasOwnProperty(key) &&
          this.filterFn.call(this.model, items[key], key, items)
        ) {
          ids.push(key);
        }
      }
    } else {
      ids = Object.keys(items);
    }
  }
  var sortFn = this.sortFn;
  if (sortFn) {
    ids.sort(function(a, b) {
      return sortFn(items[a], items[b]);
    });
  }
  return ids;
};
Filter.prototype.get = function() {
  var items = this.model._get(this.inputSegments);
  var results = [];
  if (Array.isArray(items)) {
    if (this.filterFn) {
      for (var i = 0; i < items.length; i++) {
        if (this.filterFn.call(this.model, items[i], i, items)) {
          results.push(items[i]);
        }
      }
    } else {
      results = items.slice();
    }
  } else {
    if (this.filterFn) {
      for (var key in items) {
        if (items.hasOwnProperty(key) &&
          this.filterFn.call(this.model, items[key], key, items)
        ) {
          results.push(items[key]);
        }
      }
    } else {
      for (var key in items) {
        if (items.hasOwnProperty(key)) {
          results.push(items[key]);
        }
      }
    }
  }
  if (this.sortFn) results.sort(this.sortFn);
  return results;
};
Filter.prototype.update = function(pass) {
  var ids = this.ids();
  this.model.pass(pass, true)._setDiff(this.idsSegments, ids);
};
Filter.prototype.ref = function(from) {
  this.from = from;
  this.filters.fromMap[from] = this;
  this.idsSegments = ['$filters', from.replace(/\./g, ':')];
  this.update();
  return this.model.refList(from, this.inputPath, this.idsSegments.join('.'));
};
Filter.prototype.destroy = function() {
  delete this.filters.fromMap[this.from];
  this.model.removeRefList(this.from);
  model._del(this.idsSegments);
};
