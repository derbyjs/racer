console.assert require('../util').isServer

adapters =
  db: {}
  clientId: {}
  journal: {}

exports.registerAdapter = (adapterType, type, AdapterKlass) ->
  adapters[adapterType][type] = AdapterKlass

exports.createAdapter = (adapterType, opts) ->
  if typeof opts is 'string'
    opts = type: opts
  if !opts.constructor == Object
    # Then, we passed in an Adapter directly as opts
    adapter = opts
  else
    try
      Adapter = adapters[adapterType][opts.type]
    catch err
      throw new Error "No #{adapterType} adapter found for #{opts.type}"
    if typeof Adapter isnt 'function'
      throw new Error "No #{adapterType} adapter found for #{opts.type}"
    adapter = new Adapter opts
  adapter.connect? (err) -> throw err if err
  return adapter
