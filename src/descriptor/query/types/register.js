module.exports = function register (Klass, typeName, conf) {
  var proto = Klass.prototype
    , types = proto._types = proto._types || {};
  types[typeName] = conf;

  proto.getType = function (name) {
    return this._types[name || 'find'];
  };

  proto[typeName] = function () {
    this._json.type = this.type = typeName;
    return this;
  };
};
