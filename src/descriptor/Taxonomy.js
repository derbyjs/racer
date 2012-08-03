/**
 * A Taxonomy is a registry of descriptor types. It's an approach to achieve
 * polymorphism for the logic represented here by handle, normalize, and typeOf
 * across different descriptor instances (e.g., query, pattern, search)
 */
module.exports = Taxonomy;

function Taxonomy () {
  this._types = {};
}

Taxonomy.prototype.type = function (name, conf) {
  var types = this._types;
  if (arguments.length === 1) return types[name];
  return types[name] = conf;
};

/**
 * Handles descriptors based on the descriptor types registered with the Taxonomy.
 * @param {Model|Store} repo
 * @param {String} method
 * @param {Array} descriptors
 * @optional @param {isAsync} Boolean
 */
Taxonomy.prototype.handle = function (repo, descriptors, callbacks) {
  for (var i = 0, l = descriptors.length; i < l; i++) {
    var descriptor = descriptors[i]
      , type = this.typeOf(descriptor);
    for (var method in callbacks) {
      var result = type[method](repo, descriptor)
        , fn = callbacks[method];
      if (typeof fn === 'function') fn(result);
    }
  }
};

Taxonomy.prototype.normalize = function (descriptors) {
  var normed = [];
  for (var i = 0, l = descriptors.length; i < l; i++) {
    var desc = descriptors[i]
      , type = this.typeOf(desc)
      , normalize = type.normalize;
    normed.push(normalize ? normalize(desc) : desc);
  }
  return normed;
};

Taxonomy.prototype.typeOf = function (descriptor) {
  var types = this._types;
  for (var name in types) {
    var type = types[name];
    if (type.isInstance(descriptor)) return type;
  }
};

Taxonomy.prototype.each = function (cb) {
  var types = this._types;
  for (var name in types) cb(name, types[name]);
};

