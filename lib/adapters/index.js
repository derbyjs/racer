console.assert(require('../util').isServer);

module.exports = {
  registerAdapter: registerAdapter
, createAdapter: createAdapter
};

var adapters = {
  db: {}
, clientId: {}
, journal: {}
};


function registerAdapter (adapterType, type, AdapterKlass) {
  adapters[adapterType][type] = AdapterKlass;
}

function createAdapter (adapterType, opts) {
  if (typeof opts === 'string') {
    opts = {type: opts};
  }
  var adapter, Adapter;
  if (opts.constructor != Object) {
    adapter = opts;
  } else {
    try {
      Adapter = adapters[adapterType][opts.type];
    } catch (err) {
      throw new Error('No ' + adapterType + ' adapter found for ' + opts.type);
    }
    if (typeof Adapter !== 'function') {
      throw new Error('No ' + adapterType + ' adapter found for ' + opts.type);
    }
    adapter = new Adapter(opts);
  }
  adapter.connect && adapter.connect( function (err) {
    if (err) throw err;
  });
  return adapter;
}
