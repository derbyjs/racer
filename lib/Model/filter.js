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

Model.prototype.filter = function(input, fn, ctx) {
  var inputPath = this.path(input);
  return this._filters.add(inputPath, fn, null, ctx);
};

Model.prototype.sort = function(input, fn, ctx) {
  var inputPath = this.path(input);
  return this._filters.add(inputPath, null, fn || 'asc', ctx);
};

Filter.prototype.context = function(ctx) {
  this.ctx = ctx;
  return this;
};

Model.prototype.removeAllFilters = function(subpath) {
  var segments = this._splitPath(subpath);
  var filters = this._filters.fromMap;
  for (var from in filters) {
    if (util.contains(segments, filters[from].fromSegments)) {
      filters[from].destroy();
    }
  }
};

function FromMap() {}
function Filters(model) {
  this.model = model;
  this.fromMap = new FromMap;
}

Filters.prototype.add = function(inputPath, filterFn, sortFn, ctx, skip, limit) {
  return new Filter(this, inputPath, filterFn, sortFn, ctx, skip, limit);
};

Filters.prototype.toJSON = function() {
  var out = [];
  for (var from in this.fromMap) {
    var filter = this.fromMap[from];
    // Don't try to bundle if functions were passed directly instead of by name
    if (!filter.bundle) continue;
    out.push([filter.inputPath, filter.filterName, filter.sortName, from, filter.ctx, filter._skip, filter._limit]);
  }
  return out;
};

function Filter(filters, inputPath, filterFn, sortFn, ctx, skip, limit) {
  this.filters = filters;
  this.model = filters.model.pass({$filter: this});
  this.inputPath = inputPath;
  this.inputSegments = inputPath.split('.');
  this.filterName = null;
  this.sortName = null;
  this.bundle = true;
  this.filterFn = null;
  this.sortFn = null;
  this.ctx = ctx;
  if (filterFn) this.filter(filterFn);
  if (sortFn) this.sort(sortFn);
  this.idsSegments = null;
  this.from = null;
  this.fromSegments = null;
  this._skip = skip || null;
  this._limit = limit || null;
}

Filter.prototype.filter = function(fn) {
  if (typeof fn === 'function') {
    this.filterFn = fn;
    this.bundle = false;
    return this;
  }
  if (typeof fn === 'string') {
    this.filterName = fn;
    this.filterFn = this.model._namedFns[fn];
    if (!this.filterFn) {
      var err = new TypeError('Filter function not found: ' + fn);
      this.model.emit('error', err);
    }
  }
  return this;
};

Filter.prototype.sort = function(fn) {
  if (!fn) fn = 'asc';
  if (typeof fn === 'function') {
    this.sortFn = fn;
    this.bundle = false;
    return this;
  }
  if (typeof fn === 'string') {
    this.sortName = fn;
    this.sortFn = this.model._namedFns[fn];
    if (!this.sortFn) {
      var err = new TypeError('Sort function not found: ' + fn);
      this.model.emit('error', err);
    }
  }
  return this;
};

Filter.prototype.skip = function(skip, limit) {
  this._skip = skip;
  this._limit = limit || this._limit;
  if(this.from) this.update();
  return this;
};

Filter.prototype.limit = function(limit, skip) {
  this._limit = limit;
  this._skip = skip || this._skip;
  if(this.from) this.update();
  return this;
};

Filter.prototype.sort = function(fn) {
  if (!fn) fn = 'asc';
  if (typeof fn === 'function') {
    this.sortFn = fn;
    this.bundle = false;
    return this;
  }
  if (typeof fn === 'string') {
    this.sortName = fn;
    this.sortFn = this.model._namedFns[fn];
    if (!this.sortFn) {
      var err = new TypeError('Sort function not found: ' + fn);
      this.model.emit('error', err);
    }
  }
  return this;
};

Filter.prototype.ids = function() {
  var items = this.model._get(this.inputSegments);
  var ids = [];
  var ctx = typeof this.ctx !== 'undefined' ? util.copyObject(this.ctx) : {};
  if (!items) return ids;
  if (Array.isArray(items)) {
    if (this.filterFn) {
      for (var i = 0; i < items.length; i++) {
        if (this.filterFn.call(this.model, items[i], i, items, ctx)) {
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
          this.filterFn.call(this.model, items[key], key, items, ctx)
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
      return sortFn(items[a], items[b], ctx);
    });
  }
  if(this._skip || this._limit) {
    var args = [this._skip || 0];
    if(this._limit) args.push((this._skip || 0) + this._limit);
    ids = Array.prototype.slice.apply(ids, args);
  }
  return ids;
};

Filter.prototype.get = function() {
  var items = this.model._get(this.inputSegments);
  var results = [];
  var ctx = typeof this.ctx !== 'undefined' ? util.copyObject(this.ctx) : {};
  var sortFn = this.sortFn;
  if (Array.isArray(items)) {
    if (this.filterFn) {
      for (var i = 0; i < items.length; i++) {
        if (this.filterFn.call(this.model, items[i], i, items, ctx)) {
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
          this.filterFn.call(this.model, items[key], key, items, ctx)
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
  if (sortFn) results.sort(function (a, b) {
    return sortFn(a, b, ctx);
  });
  if(this._skip || this._limit) {
    var args = [this._skip || 0];
    if(this._limit) args.push((this._skip || 0) + this._limit);
    results = Array.prototype.slice.apply(results, args);
  }
  return results;
};

Filter.prototype.update = function(pass) {
  var ids = this.ids();
  this.model.pass(pass, true)._setDiff(this.idsSegments, ids);
};

Filter.prototype.ref = function(from) {
  from = this.model.path(from);
  this.from = from;
  this.fromSegments = from.split('.');
  this.filters.fromMap[from] = this;
  this.idsSegments = ['$filters', from.replace(/\./g, '|')];
  this.update();
  return this.model.refList(from, this.inputPath, this.idsSegments.join('.'), {autoPatchIndices: true});
};

Filter.prototype.destroy = function() {
  delete this.filters.fromMap[this.from];
  this.model.removeRefList(this.from);
  this.model._del(this.idsSegments);
};
