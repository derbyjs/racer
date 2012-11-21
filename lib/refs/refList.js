var util = require('../util')
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
  var getter = function (data, pathToRef, rest, refEmitter, prevRests) {
    var toOut = treeLookup(data, to)
      , domain = toOut.node || {} // formerly obj
      , dereffed = toOut.path

      , keyOut = treeLookup(data, key)
      , pointerList = keyOut.node
      , dereffedKey = keyOut.path
      ;

    if (!rest.length) {
      var node = [];
      if (pointerList) {
        // returned node should be an array of dereferenced documents
        for (var k = 0, len = pointerList.length; k < len; k++) {
          var id = pointerList[k]
            , docToAdd
            ;
          if (domain.constructor == Object) {
            docToAdd = domain[id];
          } else if (Array.isArray(domain)) {
            docToAdd = domain[indexOfFn(domain, function (doc) { return doc.id == id; })]
          } else {
            throw new TypeError();
          }
          node.push(docToAdd);
        }
      }

      var out = {};

      // Look ahead to see if we need to access a member of this refList and
      // modify the property chain so it makes sense in the context of the
      // dereferenced refList
      var prevRest = lastNonEmptyList(prevRests);
      if (prevRest) {
        var nextProp = prevRest[0];
        if (nextProp === 'length') {
          out.node = node;
          out.path = pathToRef;
        } else {
          var refListIndex = parseInt(nextProp)
            , id = pointerList[refListIndex];
          prevRest[0] = id;
          out.node = domain;
          out.path = dereffed;
        }
      } else {
        out.node = node;
        out.path = pathToRef;
      }

      refEmitter && refEmitter.emit('refList', node, pathToRef, rest, pointerList, dereffed, dereffedKey);

      if (typeof node === 'undefined') out.halt = true;
      return out;
    } else {
      if (rest.length === 1 && rest[0] === 'length') {
        rest.shift();
        return {node: pointerList ? pointerList.length : 0, path: pathToRef + '.length'};
      }
      var index = parseInt(rest.shift());
      var id = pointerList && pointerList[index];
      var node = domain && domain[id];
      refEmitter && refEmitter.emit('refListMember', node, pointerList, dereffedKey + '.' + index, dereffed, id, rest);
      id = pointerList && pointerList[index];
      var out = {node: node, path: dereffed + '.' + id};
      if (typeof node === 'undefined') out.halt = true;
      return out;
    }
  };

  return getter;
}

function lastNonEmptyList (listOfLists) {
  if (!listOfLists) return;
  var i = listOfLists.length;
  if (!i) return;
  while (i--) {
    var list = listOfLists[i];
    if (list.length) return list;
  }
}
