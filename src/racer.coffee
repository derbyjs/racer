{mergeAll, isServer} = util = require './util'
require 'es5-shim' unless isServer
{EventEmitter} = require 'events'
plugin = require './plugin'

racer = module.exports = new EventEmitter

mergeAll racer, plugin,
  protected:
    Model: require './Model'
  util: util

# Note that this plugin is passed by string to prevent
# Browserify from including it
racer.use(__dirname + '/racer.server')  if isServer

racer
  .use(require './mutators')
  .use(require './refs')
  .use(require './pubSub')
  .use(require './txns')

racer.use(__dirname + '/adapters/pubsub-memory')  if isServer

# The browser module must be included last, since it creates a
# model instance, before which all plugins should be included
racer.use(require './racer.browser')  unless isServer
