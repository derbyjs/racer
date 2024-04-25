var util = require('../util');
import { Model } from './Model';
import { type Segments } from './types';
import * as defaultFns from './defaultFns';
import type { Path, PathLike } from '../types';

interface PaginationOptions {
  skip?: number;
  limit?: number;
}

type FilterFn<S> =
  | ((item: S, key: string, object: { [key: string]: S }) => boolean)
  | null;
type SortFn<S> = (a: S, B: S) => number;

declare module './Model' {
  interface Model {
    /**
     * Creates a live-updating list from items in an object, which results in
     * automatically updating as the input items change.
     *
     * @param inputPath - Path pointing to an object or array. The path's value is
     *   retrieved via model.get(), and each item checked against filter function
     * @param additionalInputPaths - Other parameters can be set in the model, and
     *   the filter function will be re-evaluated when these parameters change as well.
     * @param options
     *   skip - The number of first results to skip
     *   limit - The maximum number of results. A limit of zero is equivalent to no limit.
     * @param fn - A function or the name of a function defined via model.fn(). The function
     *   should have the arguments function(item, key, object, additionalInputs...)
     *
     * @see https://derbyjs.com/docs/derby-0.10/models/filters-and-sorts
     */
    filter<S>(
      inputPath: PathLike,
      additionalInputPaths: PathLike[],
      options: PaginationOptions,
      fn?: FilterFn<S>
    ): Filter<S>;
    filter<S>(
      inputPath: PathLike,
      additionalInputPaths: PathLike[],
      fn?: FilterFn<S>
    ): Filter<S>;
    filter<S>(
      inputPath: PathLike,
      options: PaginationOptions,
      fn?: FilterFn<S>
    ): Filter<S>;
    filter<S>(
      inputPath: PathLike,
      fn?: FilterFn<S>
    ): Filter<S>;

    removeAllFilters: (subpath: Path) => void;

    /**
     * Creates a live-updating list from items in an object, which results in
     * automatically updating as the input items change. The results are sorted by ascending order (default) or by a provided 'fn' parameter.
     *
     * @param inputPath - Path pointing to an object or array. The path's value is
     *   retrieved via model.get(), and each item checked against filter function
     * @param additionalInputPaths - Other parameters can be set in the model, and
     *   the filter function will be re-evaluated when these parameters change as well.
     * @param options
     *   skip - The number of first results to skip
     *   limit - The maximum number of results. A limit of zero is equivalent to no limit.
     * @param fn - A function or the name of a function defined via model.fn().
     *
     * @see https://derbyjs.com/docs/derby-0.10/models/filters-and-sorts
     */
    sort<S>(
      inputPath: PathLike,
      additionalInputPaths: PathLike[],
      options: PaginationOptions,
      fn: SortFn<S>
    ): Filter<S>;
    sort<S>(
      inputPath: PathLike,
      additionalInputPaths: PathLike[],
      fn: SortFn<S>
    ): Filter<S>;
    sort<S>(inputPath: PathLike, options: PaginationOptions, fn: SortFn<S>): Filter<S>;
    sort<S>(inputPath: PathLike, fn: SortFn<S>): Filter<S>;

    _filters: Filters;
    _removeAllFilters: (segments: Segments) => void;
  }
}

Model.INITS.push(function(model: Model) {
  model.root._filters = new Filters(model);
  model.on('all', filterListener);
  function filterListener(segments, event) {
    var passed = event.passed;
    var map = model.root._filters.fromMap;
    for (var path in map) {
      var filter = map[path];
      if (passed.$filter === filter) continue;
      if (
        util.mayImpact(filter.segments, segments) ||
        (filter.inputsSegments && util.mayImpactAny(filter.inputsSegments, segments))
      ) {
        filter.update(passed);
      }
    }
  }
});

function parseFilterArguments(model, args) {
  let fn, options, inputPaths;
  // first arg always path
  var path = model.path(args.shift());
  if (!args.length) {
    return {
      path: path,
      inputPaths: null,
      options: options,
      fn: () => true,
    };
  }
  let last = args[args.length - 1];
  if (typeof last === 'function') {
    // fn null if optional
    // filter can be string
    fn = args.pop();
  }
  if  (args.length && fn == null) {
    // named function
    fn = args.pop();
  }
  last = args[args.length - 1];
  if (!model.isPath(last) && !Array.isArray(last)) {
    options = args.pop();
  }
  if (args.length === 1 && Array.isArray(args[0])) {
    // inputPaths provided as one array:
    //   model.filter(inputPath, [inputPath1, inputPath2], fn)
    inputPaths = args[0];
  } else {
    // inputPaths provided as var-args:
    //   model.filter(inputPath, inputPath1, inputPath2, fn)
    inputPaths = args;
  }
  var i = inputPaths.length;
  while (i--) {
    inputPaths[i] = model.path(inputPaths[i]);
  }
  return {
    path: path,
    inputPaths: (inputPaths.length) ? inputPaths : null,
    options: options,
    fn: fn
  };
}

Model.prototype.filter = function() {
  var args = Array.prototype.slice.call(arguments);
  var parsed = parseFilterArguments(this, args);
  return this.root._filters.add(
    parsed.path,
    parsed.fn,
    null,
    parsed.inputPaths,
    parsed.options
  );
};

Model.prototype.sort = function() {
  var args = Array.prototype.slice.call(arguments);
  var parsed = parseFilterArguments(this, args);
  return this.root._filters.add(
    parsed.path,
    null,
    parsed.fn || 'asc',
    parsed.inputPaths,
    parsed.options
  );
};

Model.prototype.removeAllFilters = function(subpath) {
  var segments = this._splitPath(subpath);
  this._removeAllFilters(segments);
};
Model.prototype._removeAllFilters = function(segments) {
  var filters = this.root._filters.fromMap;
  for (var from in filters) {
    if (util.contains(segments, filters[from].fromSegments)) {
      filters[from].destroy();
    }
  }
};

class FromMap {}

class Filters{
  model: Model;
  fromMap: FromMap;
  constructor(model) {
    this.model = model;
    this.fromMap = new FromMap();
  }

  add(path: Path, filterFn, sortFn, inputPaths, options) {
    return new Filter(this, path, filterFn, sortFn, inputPaths, options);
  };

  toJSON() {
    var out = [];
    for (var from in this.fromMap) {
      var filter = this.fromMap[from];
      // Don't try to bundle if functions were passed directly instead of by name
      if (!filter.bundle) continue;
      var args = [from, filter.path, filter.filterName, filter.sortName, filter.inputPaths];
      if (filter.options) args.push(filter.options);
      out.push(args);
    }
    return out;
  };
}

export class Filter<T> {
  bundle: boolean;
  filterFn: any;
  filterName: string;
  filters: any;
  from: string;
  fromSegments: string[]
  idsSegments: Segments;
  inputPaths: any;
  inputsSegments: Segments[];
  limit: number;
  model: Model<T>;
  options: any;
  path: string;
  segments: Segments;
  skip: number;
  sortFn: any;
  sortName: string;

  constructor(filters, path, filterFn, sortFn, inputPaths, options) {
    this.filters = filters;
    this.model = filters.model.pass({$filter: this});
    this.path = path;
    this.segments = path.split('.');
    this.filterName = null;
    this.sortName = null;
    this.bundle = true;
    this.filterFn = null;
    this.sortFn = null;
    this.inputPaths = inputPaths;
    this.inputsSegments = null;
    if (inputPaths) {
      this.inputsSegments = [];
      for (var i = 0; i < this.inputPaths.length; i++) {
        var segments = this.inputPaths[i].split('.');
        this.inputsSegments.push(segments);
      }
    }
    this.options = options;
    this.skip = options && options.skip;
    this.limit = options && options.limit;
    if (filterFn) this.filter(filterFn);
    if (sortFn) this.sort(sortFn);
    this.idsSegments = null;
    this.from = null;
    this.fromSegments = null;
  }

  filter(fn) {
    if (typeof fn === 'function') {
      this.filterFn = fn;
      this.bundle = false;
      return this;
    } else if (typeof fn === 'string') {
      this.filterName = fn;
      this.filterFn = this.model.root._namedFns[fn] || defaultFns[fn];
      if (!this.filterFn) {
        throw new TypeError('Filter function not found: ' + fn);
      }
    }
    return this;
  };

  sort(fn) {
    if (!fn) fn = 'asc';
    if (typeof fn === 'function') {
      this.sortFn = fn;
      this.bundle = false;
      return this;
    } else if (typeof fn === 'string') {
      this.sortName = fn;
      this.sortFn = this.model.root._namedFns[fn] || defaultFns[fn];
      if (!this.sortFn) {
        throw new TypeError('Sort function not found: ' + fn);
      }
    }
    return this;
  };
  
  _slice(results) {
    if (this.skip == null && this.limit == null) return results;
    var begin = this.skip || 0;
    // A limit of zero is equivalent to setting no limit
    var end;
    if (this.limit) end = begin + this.limit;
    return results.slice(begin, end);
  };
  
  getInputs() {
    if (!this.inputsSegments) return;
    var inputs = [];
    for (var i = 0, len = this.inputsSegments.length; i < len; i++) {
      var input = this.model._get(this.inputsSegments[i]);
      inputs.push(input);
    }
    return inputs;
  };
  
  callFilter(items, key, inputs) {
    var item = items[key];
    return (inputs) ?
      this.filterFn.apply(this.model, [item, key, items].concat(inputs)) :
      this.filterFn.call(this.model, item, key, items);
  };
  
  ids(): string[] {
    var items = this.model._get(this.segments);
    var ids = [];
    if (!items) return ids;
    if (Array.isArray(items)) {
      throw new Error('model.filter is not currently supported on arrays');
    }
    if (this.filterFn) {
      var inputs = this.getInputs();
      for (var key in items) {
        if (items.hasOwnProperty(key) && this.callFilter(items, key, inputs)) {
          ids.push(key);
        }
      }
    } else {
      ids = Object.keys(items);
    }
    var sortFn = this.sortFn;
    if (sortFn) {
      ids.sort(function(a, b) {
        return sortFn(items[a], items[b]);
      });
    }
    return this._slice(ids);
  };
  
  get<S = unknown>(): S[] {
    var items = this.model._get(this.segments);
    var results = [];
    if (Array.isArray(items)) {
      throw new Error('model.filter is not currently supported on arrays');
    }
    if (this.filterFn) {
      var inputs = this.getInputs();
      for (var key in items) {
        if (items.hasOwnProperty(key) && this.callFilter(items, key, inputs)) {
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
    if (this.sortFn) results.sort(this.sortFn);
    return this._slice(results);
  };
  
  update(pass?: any) {
    var ids = this.ids();
    this.model.pass(pass, true)._setArrayDiff(this.idsSegments, ids);
  };
  
  ref(from) {
    from = this.model.path(from);
    this.from = from;
    this.fromSegments = from.split('.');
    this.filters.fromMap[from] = this;
    this.idsSegments = ['$filters', from.replace(/\./g, '|')];
    this.update();
    return this.model.refList(from, this.path, this.idsSegments.join('.'));
  };
  
  destroy() {
    delete this.filters.fromMap[this.from];
    this.model._removeRef(this.idsSegments);
    this.model._del(this.idsSegments);
  };
}
