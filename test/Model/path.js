var expect = require('../util').expect;
var Model = require('../../lib/Model');

describe('path methods', function() {
  describe('path', function() {
    it('returns empty string for model without scope', function() {
      var model = new Model();
      expect(model.path()).equal('');
    });
  });
  describe('scope', function() {
    it('returns a child model with the absolute scope', function() {
      var model = new Model();
      var scoped = model.scope('foo.bar.baz');
      expect(model.path()).equal('');
      expect(scoped.path()).equal('foo.bar.baz');
    });
    it('supports segments as separate arguments', function() {
      var model = new Model();
      var scoped = model.scope('foo', 'bar', 'baz');
      expect(model.path()).equal('');
      expect(scoped.path()).equal('foo.bar.baz');
    });
    it('overrides a previous scope', function() {
      var model = new Model();
      var scoped = model.scope('foo', 'bar', 'baz');
      var scoped2 = scoped.scope('colors', 4);
      expect(scoped2.path()).equal('colors.4');
    });
    it('supports no arguments', function() {
      var model = new Model();
      var scoped = model.scope('foo', 'bar', 'baz');
      var scoped2 = scoped.scope();
      expect(scoped2.path()).equal('');
    });
  });
  describe('at', function() {
    it('returns a child model with the relative scope', function() {
      var model = new Model();
      var scoped = model.at('foo.bar.baz');
      expect(model.path()).equal('');
      expect(scoped.path()).equal('foo.bar.baz');
    });
    it('supports segments as separate arguments', function() {
      var model = new Model();
      var scoped = model.at('foo', 'bar', 'baz');
      expect(model.path()).equal('');
      expect(scoped.path()).equal('foo.bar.baz');
    });
    it('overrides a previous scope', function() {
      var model = new Model();
      var scoped = model.at('colors');
      var scoped2 = scoped.at(4);
      expect(scoped2.path()).equal('colors.4');
    });
    it('supports no arguments', function() {
      var model = new Model();
      var scoped = model.at('foo', 'bar', 'baz');
      var scoped2 = scoped.at();
      expect(scoped2.path()).equal('foo.bar.baz');
    });
  });
});
