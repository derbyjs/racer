var util = require('../util')
  , hasKeys = util.hasKeys
  , indexOf = util.indexOf
  , indexOfFn = util.indexOfFn
  , refUtils = require('./util')
  , addListener = refUtils.addListener
  , Model = require('../Model')
  , treeLookup = require('../tree').lookup
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
   * @param {Object} data is the speculative or non-speculative data tree
   * @param {String} pathToRef is the current path to the ref function
   * @param {[String]} rest is an array of properties representing the suffix
   * path we still want to lookup up on the dereferenced lookup
   * @return {Array} {node, path}
   */
  var getter = function (data, pathToRef, rest, ee) {
    var toOut = treeLookup(data, to)
      , domain   = toOut.node || {} // formerly obj
      , dereffed = toOut.path

      , keyOut = treeLookup(data, key)
      , pointerList = keyOut.node
      , dereffedKey = keyOut.path
      ;

    if (! rest.length) {
      var node = [];
      if (pointerList) {
        // returned node should be an array of dereferenced documents
        for (var k = 0, kk = pointerList.length; k < kk; k++) {
          var id = pointerList[k];
          var docToAdd;
          if (domain.constructor == 'Object') {
            docToAdd = domain[id];
          } else if (Array.isArray(domain)) {
            docToAdd = domain[indexOfFn(domain, function (doc) { return doc.id == id; })]
          } else {
            throw new TypeError();
          }
          node.push(docToAdd);
        }
      }
      ee && ee.emit('refList', node, pathToRef, rest, pointerList);
      return {node: node, path: pathToRef};
    } else {
      if (rest.length === 1 && rest[0] === 'length') {
        rest.shift();
        return {node: pointerList ? pointerList.length : 0, path: pathToRef + '.length'};
      }
      var index = parseInt(rest.shift(), 10);
      var id = pointerList && pointerList[index];
      var node = domain && domain[id];
      ee && ee.emit('refListMember', node, pointerList, dereffedKey + '.' + index);
      id = pointerList[index];
      return {node: node, path: dereffed + '.' + id}
    }
  };

  return getter;
}
