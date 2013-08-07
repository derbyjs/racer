var Model, expect;

expect = require('../util').expect;

Model = require('../../lib/Model');

describe('Model events', function() {
  return describe('mutator events', function() {
    it('calls earlier listeners in the order of mutations', function(done) {
      var expectedPaths, model;
      model = (new Model).at('_page');
      expectedPaths = ['a', 'b', 'c'];
      model.on('change', '**', function(path) {
        expect(path).to.equal(expectedPaths.shift());
        if (!expectedPaths.length) {
          return done();
        }
      });
      model.on('change', 'a', function() {
        return model.set('b', 2);
      });
      model.on('change', 'b', function() {
        return model.set('c', 3);
      });
      return model.set('a', 1);
    });
    return it('calls later listeners in the order of mutations', function(done) {
      var expectedPaths, model;
      model = (new Model).at('_page');
      model.on('change', 'a', function() {
        return model.set('b', 2);
      });
      model.on('change', 'b', function() {
        return model.set('c', 3);
      });
      expectedPaths = ['a', 'b', 'c'];
      model.on('change', '**', function(path) {
        expect(path).to.equal(expectedPaths.shift());
        if (!expectedPaths.length) {
          return done();
        }
      });
      return model.set('a', 1);
    });
  });
});
