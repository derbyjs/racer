{EventEmitter} = require 'events'
plugin = require './plugin'
{mergeAll, isServer} = util = require './util'

racer = module.exports = new EventEmitter
mergeAll racer, plugin,

  diffMatchPatch: require './diffMatchPatch'
  Memory: require './Memory'
  Model: require './Model'
  path: require './path'
  plugin: plugin
  Promise: require './Promise'
  Serializer: require './Serializer'
  speculative: require './speculative'
  transaction: require './transaction'
  util: util

# Note that this plugin is passed by string to prevent
# Browserify from including it
racer.use(__dirname + '/racer.server')  if isServer

racer
  .use(require './mutators')
  .use(require './refs')
  .use(require './txns')
  .use(require './pubSub')
  .use(require './ot')

# The browser module must be included last, since it creates a
# model instance, before which all plugins should be included
racer.use(require './racer.browser')  unless isServer
