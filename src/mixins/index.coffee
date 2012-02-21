# A mixin is an object literal with:
# proto:       methods to add to Model.prototype
# static:      class/static methods to add to Model
# init:        called from the Model constructor
# setupSocket: invoked inside Model::_setSocket with fn signature (socket) -> ...
# accessors:   getters
# mutators:    setters
# onMixin:     called with the Klass for potential decoration

# NOTE: Order of mixins may be important because of dependencies.

exports.makeMixable = (Klass) ->
  Klass.mixins = []
  Klass.accessors = {}
  Klass.mutators = {}
  onMixins = []
  Klass.mixin = (mixin) ->
    Klass.mixins.push mixin
    mergeAll Klass::, mixin.static, mixin.proto

    for category in ['accessors', 'mutators']
      cache = Klass[category]
      if methods = mixin[category] then for name, conf of methods
        Klass::[name] = cache[name] = fn = conf.fn
        for key, value of conf
          continue if key is 'fn'
          fn[key] = value

    onMixins.push onMixin  if onMixin = mixin.onMixin
    onMixin Klass for onMixin in onMixins

    return Klass
