var util = require('../util')
  , hasKeys = util.hasKeys
  , indexOf = util.indexOf
  , refUtils = require('./util')
  , derefPath = refUtils.derefPath
  , addListener = refUtils.addListener
  , joinPaths = require('../path').join
  , Model = require('../Model')
  ;

module.exports = createRefList;

function createRefList (model, from, to, key) {
  if (!from || !to || !key) {
    throw new Error('Invalid arguments for model.refList');
  }
  var arrayMutators = Model.arrayMutator
    , getter = createGetter(from, to, key)
    , listeners = [];

  addListener(listeners, model, from, getter, key, function (regexpMatch, method, args) {
    var methodMeta = arrayMutators[method]
      , i = methodMeta && methodMeta.insertArgs;
    if (i) {
      var id, docs;
      docs = model.get(to);
      while ((id = args[i]) && id != null) {
        args[i] = (Array.isArray(docs))
                ? docs && docs[ indexOf(docs, id, function (id, doc) { return doc.id === id; })  ]
                : docs && docs[id];
        // args[i] = model.get(to + '.' + id);
        i++;
      }
    }
    return from;
  });

  addListener(listeners, model, from, getter, to + '.*', function (regexpMatch) {
    var id = regexpMatch[1]
      , i = id.indexOf('.')
      , remainder;
    if (~i) {
      remainder = id.substr(i+1);
      id = id.substr(0, i);
    }
    var pointerList = model.get(key);
    if (!pointerList) return null;
    i = pointerList.indexOf(id);
    if (i === -1) return null;
    return remainder ?
      from + '.' + i + '.' + remainder :
      from + '.' + i;
  });

  return getter;
}

function createGetter (from, to, key) {
  /**
   * This represents a ref function that is assigned as the value of the node
   * located at `path` in `data`
   *
   * @param {Function} lookup is the Memory lookup function
   * @param {Object} data is the speculative or non-speculative data tree
   * @param {String} path is the current path to the ref function
   * @param {[String]} props is the chain of properties representing a full
   * path, of which path may be just a sub path
   * @param {Number} len is the number of properties in props
   * @param {Number} i is the array index of props that we are currently at
   * @return {Array} [evaled, path, i] where
   */
  return function getter (lookup, data, path, props, len, i) {
    var basicMutators = Model.basicMutator
      , arrayMutators = Model.arrayMutator

    // Here, lookup(to, data) is called in order for derefPath to work because
    // derefPath looks for data.$deref, which is lazily re-assigned on a lookup
      , obj = lookup(to, data) || {}
      , dereffed = derefPath(data, to);
    data.$deref = null;
    var pointerList = lookup(key, data)
      , dereffedKey = derefPath(data, key)
      , currPath, id;

    if (i === len) {
      // Method is on the refList itself
      currPath = joinPaths(dereffed, props.slice(i));

      // TODO The mutation of args in here is bad software engineering. It took
      // me a while to track down where args was getting transformed. Fix this.
      data.$deref = function (method, args, model) {
        if (!method || (method in basicMutators)) return path;

        var mutator, j, arg, indexArgs;
        if (mutator = arrayMutators[method]) {
          // Handle index args if they are specified by id
          if (indexArgs = mutator.indexArgs) for (var k = 0, kk = indexArgs.length; k < kk; k++) {
            j = indexArgs[k]
            arg = args[j];
            if (!arg) continue;
            id = arg.id;
            if (id == null) continue;
            // Replace id arg with the current index for the given id
            var idIndex = pointerList.indexOf(id);
            if (idIndex !== -1) args[j] = idIndex;
          } // end if (indexArgs)

          if (j = mutator.insertArgs) while (arg = args[j]) {
            id = (arg.id != null)
               ? arg.id
               : (arg.id = model.id());
            // Set the object being inserted if it contains any properties
            // other than id
            if (hasKeys(arg, 'id')) {
              model.set(dereffed + '.' + id, arg);
            }
            args[j] = id;
            j++;
          }

          return dereffedKey;
        }

        throw new Error(method + ' unsupported on refList');
      }; // end of data.$deref function

      if (pointerList) {
        var curr = [];
        for (var k = 0, kk = pointerList.length; k < kk; k++) {
          var idVal = pointerList[k]
            , docToAdd;
          if (obj.constructor === Object) {
            docToAdd = obj[idVal];
          } else if (Array.isArray(obj)) {
            docToAdd = obj[indexOf(obj, idVal, function (id, doc) {
              // TODO: Brian to investigate. Code should be able to work without
              // checking for existence of the doc first
              return doc && doc.id === id;
            })];
          } else {
            throw new TypeError();
          }
          curr.push(docToAdd);
        }
        return [curr, currPath, i];
      }

      return [undefined, currPath, i];

    } else { // if (i !== len)
      var index = props[i++]
        , prop, curr, lastProp;

      if (pointerList && (prop = pointerList[index])) {
        curr = obj[prop];
      }

      if (i === len) {
        lastProp = props[i-1];
        if (lastProp === 'length') {
          currPath = dereffedKey + '.length';
          curr = lookup(currPath, data);
        } else {
          currPath = dereffed;
        }

        data.$deref = function (method, args, model, obj) {
          // TODO Additional model methods should be done atomically with the
          // original txn instead of making an additional txn

          var value, id;
          if (method === 'set') {
            value = args[1];
            id = (value.id != null)
               ? value.id
               : (value.id = model.id());
            if (pointerList) {
              model.set(dereffedKey + '.' + index, id);
            } else {
              model.set(dereffedKey, [id]);
            }
            return dereffed + '.' + id;
          }

          if (method === 'del') {
            id = obj.id;
            if (id == null) {
              throw new Error('Cannot delete refList item without id');
            }
            model.del(dereffedKey + '.' + index);
            return dereffed + '.' + id;
          }

          throw new Error(method + ' unsupported on refList index');
        } // end of data.$deref function

      } else { // if (i !== len)
        // Method is on a child of the refList
        currPath = (prop == null)
                 ? joinPaths(dereffed, props.slice(i))
                 : joinPaths(dereffed, prop, props.slice(i));

        data.$deref = function (method) {
          if (method && prop == null) {
            throw new Error(method + ' on undefined refList child ' + props.join('.'));
          }
          return currPath;
        };
      }

      return [curr, currPath, i];
    }
  };
}
