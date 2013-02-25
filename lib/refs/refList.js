var util = require('../util')
  , indexOf = util.indexOf
  , indexOfFn = util.indexOfFn
  , refUtils = require('./util')
  , RefListener = refUtils.RefListener
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
    , refListener = new RefListener(model, from, getter)
    , toOffset = to.length + 1;

  refListener.add(key, function (path, method, args) {
    var methodMeta = arrayMutators[method]
      , i = methodMeta && methodMeta.insertArgs;
    if (i) {
      var id, docs;
      docs = model.get(to);
      while ((id = args[i]) && id != null) {
        args[i] = (Array.isArray(docs))
          ? docs && docs[ indexOf(docs, id, function (id, doc) { return doc && doc.id === id; })  ]
          : docs && docs[id];
        // args[i] = model.get(to + '.' + id);
        i++;
      }
    }
    return from;
  });

  refListener.add(to + '.*', function (path) {
    var id = path.slice(toOffset)
      , i = id.indexOf('.')
      , remainder;
    if (~i) {
      remainder = id.substr(i+1);
      id = id.substr(0, i);
      // id can be a document id,
      // or it can be an array index if to resolves to e.b., a filter result array
      // This line is for the latter case
      id = model.get(to + '.' + id + '.id')
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
   * @param {Object} meta
   * @config {Array} [meta.prevRests]
   * @config {RefEmitter} [meta.refEmitter]
   * @return {Array} {node, path}
   */
  return function getterRefList (data, pathToRef, rest, meta) {
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
          var id = pointerList[k];
          node.push(getDoc(domain, id, to, pathToRef));
        }
      }

      if (meta.refEmitter) {
        meta.refEmitter.onRefList(node, pathToRef, rest, pointerList, dereffed, dereffedKey);
      }
      return { node: node, path: pathToRef };
    } else {
      if (rest.length === 1 && rest[0] === 'length') {
        rest.shift();
        return {node: pointerList ? pointerList.length : 0, path: pathToRef + '.length'};
      }
      var index = rest.shift()
        , id = pointerList && pointerList[index]
        , node = domain && id && getDoc(domain, id, to, pathToRef);
      if (meta.refEmitter) {
        meta.refEmitter.onRefListMember(node, pointerList, dereffedKey + '.' + index, dereffed, id, rest);
      }
      return {node: node, path: dereffed + '.' + id};
    }
  };
}
function getDoc (domain, id, to, pathToRef) {
  if (domain.constructor == Object) {
    return domain[id];
  } else if (Array.isArray(domain)) {
    return domain[indexOfFn(domain, function (doc) {
      if (!doc) {
        console.warn(new Error('Unexpected'));
        console.warn("No doc", 'domain:', domain, 'refList to path:', to, 'pathToRef:', pathToRef);
      }
      return doc && doc.id == id;
    })]
  } else {
    throw new TypeError();
  }
}