/**
 * Descriptors are different ways of expressing a data set. Racer comes bundled
 * with 2 descriptor types:
 *
 * 1. Path Patterns
 *
 *    model.subscribe('users.*.name', callback);
 *
 * 2. Queries
 *
 *    var query = model.query('users').withName('Brian');
 *    model.fetch(query, callback);
 *
 * Descriptors allow you to create expressive DSLs to write addresses to data.
 * You then pass the concrete descriptor(s) to fetch, subscribe, or snapshot.
 */
var mixinModel = require('./descriptor.Model')
  , mixinStore = __dirname + '/descriptor.Store'
  , patternPlugin = require('./pattern')
  , queryPlugin = require('./query')
  ;

exports = module.exports = plugin;

exports.useWith = {server: true, browser: true};

exports.decorate = 'racer';

function plugin (racer) {
  racer.mixin(mixinModel, mixinStore);
  racer.use(patternPlugin);
  racer.use(queryPlugin);
}
