var pathUtils             = require('../path')
  , regExpPathOrParent    = pathUtils.regExpPathOrParent
  , regExpPathsOrChildren = pathUtils.regExpPathsOrChildren
  , joinPaths             = pathUtils.join
  , treeLookup            = require('../tree').lookup
  , refUtils              = require('./util')
  , assertPrivateRefPath  = refUtils.assertPrivateRefPath
  , createRef             = require('./ref')
  , createRefList         = require('./refList')
  , equal                 = require('../util').equal
  , unbundledFunction     = require('../bundle/util').unbundledFunction
  , TransformBuilder      = require('../descriptor/query/TransformBuilder') // ugh - leaky abstraction
  , EventEmitter          = require('events').EventEmitter
  ;

exports = module.exports = plugin;
exports.useWith = { server: true, browser: true };
exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixin);
}

var mixin = {
  type: 'Model'

, server: __dirname + '/refs.server'
, events: {
    init: function (model) {
      // [[from, get, item], ...]
      model._refsToBundle = [];

      // [['fn', path, inputs..., cb.toString()], ...]
      model._fnsToBundle = [];

      var Model = model.constructor;

      for (var method in Model.mutator) {
        model.on(method, (function (method) {
          return function () {
            model.emit('mutator', method, arguments);
          };
        })(method));
      }

      var memory = model._memory;

      // De-reference transactions to operate on their absolute path
      model.on('beforeTxn', function (method, args) {
        var path = args[0];
        if (!path) return; // TODO Will path ever be falsy?

        var ee = new EventEmitter();
        ee.on('refList', function (node, pathToRef, rest, pointerList) {
          if (!rest.length) {
            var basicMutators = Model.basicMutator;
            if (!method || (method in basicMutators)) return;

            var arrayMutators = Model.arrayMutator
              , mutator = arrayMutators[method];
            if (! mutator) throw new Error(method + ' unsupported on refList');

            var j, arg, indexArgs;
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
          }
        });
        ee.on('refListMember', function (node, pointerList, memberKeyPath) {
          // TODO Additional model methods should be done atomically with the
          // original txn instead of making an additional txn
          var id;
          if (method === 'set') {
            var origSetTo = args[1];
            id = (origSetTo.id != null)
               ? origSetTo.id
               : (origSetTo.id = model.id());
            model.set(memberKeyPath, id);
          } else if (method === 'del') {
            id = node.id;
            if (id == null) {
              throw new Error('Cannot delete refList item without id');
            }
            model.del(memberKeyPath);
          } else {
            throw new Error(method + ' unsupported on refList index');
          }
        });

        ee.on('refWithKey', function (node, dereffedToPath, id, rest, hardLink) {
          var dereffedRefPath = dereffedToPath + '.' + id;
          if (hardLink || ! ( // unless we're a hardLink or...
            !rest.length && method === 'del' // ...deleting a ref
          )) {
            args[0] = joinPaths(dereffedRefPath, rest);
            if (id && (!node || node.id !== id)) {
              if (method === 'set') {
                model.set(dereffedRefPath + '.id', id);
              }
            }
          }
        });
        ee.on('refWithoutKey', function (node, dereffedToPath, rest, hardLink) {
          if (hardLink || ! ( // unless we're a hardLink or...
            !rest.length && method === 'del' // ...deleting a ref
          )) {
            args[0] = joinPaths(dereffedToPath, rest);
            console.log("SET ARGS", joinPaths(dereffedToPath, rest));
          } else {
            console.log("DONT SET ARGS", joinPaths(dereffedToPath, rest), args[0]);
          }
        });
        var data = model._specModel();
        var path = args[0];
        var getRef = false;
        // If we are setting a ref or refList or model.fn
        if (method === 'set' && typeof args[1] === 'function') {
          treeLookup(data.world, path, {getRef: getRef, skipLast: true}, ee);
        } else {
          treeLookup(data.world, path, {getRef: getRef}, ee);
        }
      });
    }

  , bundle: function (model) {
      var onLoad       = model._onLoad
        , refsToBundle = model._refsToBundle
        , fnsToBundle  = model._fnsToBundle;

      for (var i = 0, l = refsToBundle.length; i < l; i++) {
        var triplet = refsToBundle[i]
          , from    = triplet[0]
          , getter  = triplet[1]
          , item    = triplet[2];
        if (model._getRef(from) === getter) {
          onLoad.push(item);
        }
      }

      for (i = 0, l = fnsToBundle.length; i < l; i++) {
        var item = fnsToBundle[i];
        if (item) onLoad.push(item);
      }
    }
  }

, proto: {
    /**
     * Assuming that a ref getter was assigned to `path`, this function will
     * return that ref getter function.
     * @param {String} path
     * @return {Function} the ref getter
     */
    _getRef: function (path) {
      // The 3rd argument `true` below tells Memory#get to return the ref
      // getter function, instead of invoking the getter function and resolve
      // the dereferenced value of the ref.
      return this._memory.get(path, this._specModel(), true);
    }

    /**
     * @param {String} path
     * @param {Boolean} getRef
     * @return {String}
     */
  , dereference: function (path, getRef) {
      if (!getRef) getRef = false;
      var data = this._specModel();
      return treeLookup(data.world, path, {getRef: getRef}).path;
    }

    /**
     * Creates a ref at `from` that points to `to`, with an optional `key`
     * @param {String} from path
     * @param {String} to path
     * @param {String} @optional key path
     * @param {Boolean} hardLink
     * @return {Model} a model scope scoped to `from`
     */
  , ref: function (from, to, key, hardLink) {
      return this._createRef(createRef, 'ref', from, to, key, hardLink);
    }

    /**
     * Creates a refList at `from` with an array of pointers at `key` that
     * point to documents in `to`.
     * @param {String} from path
     * @param {String} to path
     * @param {String} key path
     * @param {Boolean} hardLink
     * @return {Model} a model scope scoped to `from`
     */
  , refList: function (from, to, key, hardLink) {
      return this._createRef(createRefList, 'refList', from, to, key, hardLink);
    }

    /**
     * @param {Function} refFactory
     * @param {String} refType is either 'ref' or 'refList'
     * @param {String} from path
     * @param {String} to path
     * @param {key} key path
     * @param {Boolean} hardLink
     * @return {Model} a model scope scoped to the `from` path
     */
  , _createRef: function (refFactory, refType, from, to, key, hardLink) {
      // Normalize scoped model arguments
      if (from._at) {
        from = from._at;
      } else if (this._at) {
        from = this._at + '.' + from;
      }
      if (to instanceof TransformBuilder) {
        var builder = to;
        to = to.path();
      } else if (to._at) {
        to = to._at;
      }
      if (key && key._at) key = key._at;

      var model = this._root;

      assertPrivateRefPath(model, from, refType);
      var getter = refFactory(model, from, to, key, hardLink);

      model.setRefGetter(from, getter);

      if (builder) {
        // This is used for server-side bundling of filters
        if (this._onCreateComputedRef) this._onCreateComputedRef(from, builder, getter);
      } else {
        // The server model adds [from, getter, [refType, from, to, key]] to
        // this._refsToBundle
        if (this._onCreateRef) this._onCreateRef(refType, from, to, key, getter);
      }

      return model.at(from);
    }

  , setRefGetter: function (path, getter) {
      var self = this;
      // Prevent emission of the next set event, since we are setting the
      // dereferencing function and not its value.
      var listener = this.on('beforeTxn', function (method, args) {
        // Supress emission of set events when setting a function, which is
        // what happens when a ref is created
        if (method === 'set' && args[1] === getter) {
          args.cancelEmit = true;
          self.removeListener('beforeTxn', listener);
        }
      });

      // Now, set the dereferencing function
      var prevValue = this.set(path, getter);
      // Emit a set event with the expected de-referenced values
      var newValue = this.get(path);
      this.emit('set', [path, newValue], prevValue, true);
    }

  , _loadComputedRef: function (from, source) {
    var builder = TransformBuilder.fromJson(this, source);
    this.ref(from, builder);
  }

    /**
     * TODO
     * Works similar to model.fn(inputs..., fn) but without having to declare
     * inputs. This means that fn also takes no arguments
     */
  , autofn: function (fn) {
      throw new Error('Unimplemented');
      autodep(this, fn);
    }

    /**
     * model.fn(inputs... ,fn);
     *
     * Defines a reactive value that depends on the paths represented by
     * `inputs`, which are used by `fn` to re-calculate a return value every
     * time any of the `inputs` change.
     */
  , fn: function (/* inputs..., fn */) {
      var arglen = arguments.length
        , inputs = Array.prototype.slice.call(arguments, 0, arglen-1)
        , fn = arguments[arglen-1];

      // Convert scoped models into paths
      for (var i = 0, l = inputs.length; i < l; i++) {
        var scopedPath = inputs[i]._at;
        if (scopedPath) inputs[i] = scopedPath;
      }

      var path = inputs.shift()
        , model = this._root;

      // If we are a scoped model, scoped to this._at
      if (this._at) path = this._at + '.' + path;

      assertPrivateRefPath(this, path, 'fn');
      if (typeof fn === 'string') {
        fn = unbundledFunction(fn);
      }
      return model._createFn(path, inputs, fn);
    }

    /**
     * @param {String} path to the reactive value
     * @param {[String]} inputs is a list of paths from which the reactive
     * value is calculated
     * @param {Function} fn returns the reactive value at `path` calculated
     * from the values at the paths defined by `inputs`
     */
  , _createFn: function (path, inputs, fn, destroy) {
      var prevVal, currVal
        , reSelf = regExpPathOrParent(path)
        , reInput = regExpPathsOrChildren(inputs)
        , destroy = this._onCreateFn && this._onCreateFn(path, inputs, fn)
        , self = this;

      var listener = this.on('mutator', function (mutator, _arguments) {
        var mutatorPath = _arguments[0][0];
        // Ignore mutations created by this reactive function
        if (_arguments[3] === listener) return;

        // Remove reactive function if something else sets the value of its
        // output path. We get the current value here, since a mutator might
        // operate on the path or the parent path that does not actually affect
        // the reactive function. The equal function is true if the objects are
        // identical or if they are both NaN
        if (reSelf.test(mutatorPath) && ! equal(self.get(path), currVal)) {
          self.removeListener('mutator', listener);
          return destroy && destroy();
        }

        if (reInput.test(mutatorPath)) {
          currVal = updateVal();
        }
      });

      var model = this.pass(listener);

      var updateVal = function () {
        prevVal = currVal;
        var inputVals = [];
        for (var i = 0, l = inputs.length; i < l; i++) {
          inputVals.push(self.get(inputs[i]));
        }
        currVal = fn.apply(null, inputVals);
        if (equal(prevVal, currVal)) return currVal;
        model.set(path, currVal);
        return currVal;
      };
      return updateVal();
    }
  }
};
