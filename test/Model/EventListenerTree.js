var expect = require('../util').expect;
var EventListenerTree = require('../../lib/Model/EventListenerTree');

describe('EventListenerTree', function() {
  describe('addListener', function() {
    it('adds a listener object at the root', function() {
      var tree = new EventListenerTree();
      var listener = {};
      tree.addListener([], listener);
      expect(tree.getListeners([])).eql([listener]);
      expect(tree.children).eql(null);
    });
    it('only a listener object once', function() {
      var tree = new EventListenerTree();
      var listener = {};
      tree.addListener([], listener);
      tree.addListener([], listener);
      expect(tree.getListeners([])).eql([listener]);
      expect(tree.children).eql(null);
    });
    it('adds a listener object at a path', function() {
      var tree = new EventListenerTree();
      var listener = {};
      tree.addListener(['colors'], listener);
      expect(tree.getListeners([])).eql([]);
      expect(tree.getListeners(['colors'])).eql([listener]);
    });
    it('adds a listener object at a subpath', function() {
      var tree = new EventListenerTree();
      var listener = {};
      tree.addListener(['colors', 'green'], listener);
      expect(tree.getListeners([])).eql([]);
      expect(tree.getListeners(['colors'])).eql([]);
      expect(tree.getListeners(['colors', 'green'])).eql([listener]);
    });
  });
  describe('removeListener', function() {
    it('can be called before addListener', function() {
      var tree = new EventListenerTree();
      var listener = {};
      tree.removeListener(['colors', 'green'], listener);
      expect(tree.getListeners(['colors', 'green'])).eql([]);
      expect(tree.children).eql(null);
    });
    it('removes listener at root', function() {
      var tree = new EventListenerTree();
      var listener = {};
      tree.addListener([], listener);
      expect(tree.getListeners([])).eql([listener]);
      tree.removeListener([], listener);
      expect(tree.getListeners([])).eql([]);
    });
    it('removes listener at subpath', function() {
      var tree = new EventListenerTree();
      var listener = {};
      tree.addListener(['colors', 'green'], listener);
      expect(tree.getListeners(['colors', 'green'])).eql([listener]);
      tree.removeListener(['colors', 'green'], listener);
      expect(tree.children).eql(null);
    });
    it('removes listener at subpath with remaining peers', function() {
      var tree = new EventListenerTree();
      tree.addListener(['colors', 'green'], 'listener1');
      tree.addListener(['colors', 'red'], 'listener2');
      tree.removeListener(['colors', 'green'], 'listener1');
      expect(tree.getListeners(['colors', 'green'])).eql([]);
      expect(tree.getListeners(['colors', 'red'])).eql(['listener2']);
    });
    it('does not remove listener if not found with one listener', function() {
      var tree = new EventListenerTree();
      tree.addListener(['colors', 'green'], 'listener1');
      expect(tree.getListeners(['colors', 'green'])).eql(['listener1']);
      tree.removeListener(['colors', 'green'], 'listener2');
      expect(tree.getListeners(['colors', 'green'])).eql(['listener1']);
    });
    it('does not remove listener if not found with multiple listeners', function() {
      var tree = new EventListenerTree();
      tree.addListener(['colors', 'green'], 'listener1');
      tree.addListener(['colors', 'green'], 'listener2');
      expect(tree.getListeners(['colors', 'green'])).eql(['listener1', 'listener2']);
      tree.removeListener(['colors', 'green'], 'listener3');
      expect(tree.getListeners(['colors', 'green'])).eql(['listener1', 'listener2']);
    });
    it('removes listener with remaining peers', function() {
      var tree = new EventListenerTree();
      tree.addListener([], 'listener1');
      tree.addListener([], 'listener2');
      tree.addListener([], 'listener3');
      expect(tree.getListeners([])).eql(['listener1', 'listener2', 'listener3']);
      tree.removeListener([], 'listener2');
      expect(tree.getListeners([])).eql(['listener1', 'listener3']);
      tree.removeListener([], 'listener3');
      expect(tree.getListeners([])).eql(['listener1']);
      tree.removeListener([], 'listener1');
      expect(tree.getListeners([])).eql([]);
    });
    it('removes listener with remaining peer children', function() {
      var tree = new EventListenerTree();
      tree.addListener(['colors'], 'listener1');
      tree.addListener(['colors', 'green'], 'listener2');
      expect(tree.getListeners(['colors'])).eql(['listener1']);
      expect(tree.getListeners(['colors', 'green'])).eql(['listener2']);
      tree.removeListener(['colors'], 'listener1');
      expect(tree.getListeners(['colors'])).eql([]);
      expect(tree.getListeners(['colors', 'green'])).eql(['listener2']);
    });
  });
  describe('removeAllListeners', function() {
    it('can be called on empty root', function() {
      var tree = new EventListenerTree();
      tree.removeAllListeners([]);
    });
    it('can be called on missing node', function() {
      var tree = new EventListenerTree();
      tree.removeAllListeners(['colors', 'green']);
    });
    it('removes all listeners and children when called on root', function() {
      var tree = new EventListenerTree();
      tree.addListener([], 'listener1');
      tree.addListener(['colors'], 'listener2');
      tree.addListener(['colors', 'green'], 'listener3');
      tree.removeAllListeners([]);
      expect(tree.getListeners([])).eql([]);
      expect(tree.children).eql(null);
    });
    it('removes listeners and descendent children on path', function() {
      var tree = new EventListenerTree();
      tree.addListener([], 'listener1');
      tree.addListener(['colors'], 'listener2');
      tree.addListener(['colors', 'green'], 'listener3');
      tree.removeAllListeners(['colors']);
      expect(tree.getListeners([])).eql(['listener1']);
      expect(tree.children).eql(null);
    });
  });
  describe('getAffectedListeners', function() {
    it('returns empty array without listeners', function() {
      var tree = new EventListenerTree();
      var affected = tree.getAffectedListeners([]);
      expect(affected).eql([]);
    });
    it('returns empty array on path without node', function() {
      var tree = new EventListenerTree();
      var affected = tree.getAffectedListeners(['colors', 'green']);
      expect(affected).eql([]);
    });
    it('returns all direct listeners', function() {
      var tree = new EventListenerTree();
      tree.addListener([], 'listener1');
      tree.addListener([], 'listener2');
      var affected = tree.getAffectedListeners([]);
      expect(affected).eql(['listener1', 'listener2']);
    });
    it('removeListener stops listener from being returned', function() {
      var tree = new EventListenerTree();
      tree.addListener([], 'listener1');
      tree.addListener([], 'listener2');
      tree.removeListener([], 'listener1');
      var affected = tree.getAffectedListeners([]);
      expect(affected).eql(['listener2']);
    });
    it('returns all descendant listeners', function() {
      var tree = new EventListenerTree();
      tree.addListener(['colors', 'green'], 'listener1');
      tree.addListener(['colors', 'red'], 'listener2');
      tree.addListener(['colors', 'red'], 'listener3');
      tree.addListener([], 'listener4');
      tree.addListener(['colors'], 'listener5');
      var affected = tree.getAffectedListeners([]);
      expect(affected).eql(['listener4', 'listener5', 'listener1', 'listener2', 'listener3']);
    });
    it('returns all parent listeners in depth order', function() {
      var tree = new EventListenerTree();
      tree.addListener(['colors', 'green'], 'listener1');
      tree.addListener(['colors', 'red'], 'listener2');
      tree.addListener(['colors', 'red'], 'listener3');
      tree.addListener([], 'listener4');
      tree.addListener(['colors'], 'listener5');
      var affected = tree.getAffectedListeners(['colors', 'green']);
      expect(affected).eql(['listener4', 'listener5', 'listener1']);
    });
    it('does not return peers or peer children', function() {
      var tree = new EventListenerTree();
      tree.addListener([], 'listener1');
      tree.addListener(['colors'], 'listener2');
      tree.addListener(['colors', 'green'], 'listener3');
      tree.addListener(['textures'], 'listener4');
      tree.addListener(['textures', 'smooth'], 'listener5');
      var affected = tree.getAffectedListeners(['textures']);
      expect(affected).eql(['listener1', 'listener4', 'listener5']);
    });
  });
  describe('getDescendantListeners', function() {
    it('returns empty array without listeners', function() {
      var tree = new EventListenerTree();
      var affected = tree.getDescendantListeners([]);
      expect(affected).eql([]);
    });
    it('returns empty array on path without node', function() {
      var tree = new EventListenerTree();
      var affected = tree.getDescendantListeners(['colors', 'green']);
      expect(affected).eql([]);
    });
    it('does not return direct listeners', function() {
      var tree = new EventListenerTree();
      tree.addListener([], 'listener1');
      tree.addListener([], 'listener2');
      var affected = tree.getDescendantListeners([]);
      expect(affected).eql([]);
    });
    it('returns all descendant listeners', function() {
      var tree = new EventListenerTree();
      tree.addListener(['colors', 'green'], 'listener1');
      tree.addListener(['colors', 'red'], 'listener2');
      tree.addListener(['colors', 'red'], 'listener3');
      tree.addListener([], 'listener4');
      tree.addListener(['colors'], 'listener5');
      var affected = tree.getDescendantListeners([]);
      expect(affected).eql(['listener5', 'listener1', 'listener2', 'listener3']);
    });
    it('does not return parent or peer listeners', function() {
      var tree = new EventListenerTree();
      tree.addListener([], 'listener1');
      tree.addListener(['colors'], 'listener2');
      tree.addListener(['colors', 'green'], 'listener3');
      tree.addListener(['textures'], 'listener4');
      tree.addListener(['textures', 'smooth'], 'listener5');
      var affected = tree.getDescendantListeners(['textures']);
      expect(affected).eql(['listener5']);
    });
  });
});
