var expect = require('../util').expect;
var EventMapTree = require('../../lib/Model/EventMapTree');

describe('EventMapTree', function() {
  describe('setListener', function() {
    it('sets a listener object at the root', function() {
      var tree = new EventMapTree();
      var listener = {};
      tree.setListener([], listener);
      expect(tree.getListener([])).equal(listener);
      expect(tree.children).equal(null);
    });
    it('setting returns the previous listener', function() {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      var previous = tree.setListener([], listener1);
      expect(previous).equal(null);
      expect(tree.getListener([])).equal(listener1);
      var previous = tree.setListener([], listener2);
      expect(previous).equal(listener1);
      expect(tree.getListener([])).equal(listener2);
      expect(tree.children).equal(null);
    });
    it('sets a listener object at a path', function() {
      var tree = new EventMapTree();
      var listener = {};
      tree.setListener(['colors'], listener);
      expect(tree.getListener([])).equal(null);
      expect(tree.getListener(['colors'])).equal(listener);
    });
    it('sets a listener object at a subpath', function() {
      var tree = new EventMapTree();
      var listener = {};
      tree.setListener(['colors', 'green'], listener);
      expect(tree.getListener([])).equal(null);
      expect(tree.getListener(['colors'])).equal(null);
      expect(tree.getListener(['colors', 'green'])).equal(listener);
    });
  });
  describe('destroy', function() {
    it('can be called on empty root', function() {
      var tree = new EventMapTree();
      tree.destroy();
      expect(tree.children).eql(null);
    });
    it('removes nodes up to root', function() {
      var tree = new EventMapTree();
      tree.setListener(['colors', 'green'], 'listener1');
      var node = tree._getChild(['colors', 'green']);
      node.destroy();
      expect(tree.children).eql(null);
    });
    it('can be called on child node repeatedly', function() {
      var tree = new EventMapTree();
      tree.setListener(['colors', 'green'], 'listener1');
      var node = tree._getChild(['colors', 'green']);
      node.destroy();
      node.destroy();
    });
    it('does not remove parent nodes with existing listeners', function() {
      var tree = new EventMapTree();
      tree.setListener(['colors'], 'listener1');
      tree.setListener(['colors', 'green'], 'listener2');
      var node = tree._getChild(['colors', 'green']);
      node.destroy();
      node.destroy();
      expect(tree.getListener(['colors'])).eql('listener1');
    });
    it('does not remove parent nodes with other children', function() {
      var tree = new EventMapTree();
      tree.setListener(['colors', 'red'], 'listener1');
      tree.setListener(['colors', 'green'], 'listener2');
      var node = tree._getChild(['colors', 'green']);
      node.destroy();
      node.destroy();
      expect(tree.getListener(['colors', 'red'])).eql('listener1');
    });
  });
  describe('deleteListener', function() {
    it('can be called before setListener', function() {
      var tree = new EventMapTree();
      tree.deleteListener(['colors', 'green']);
      expect(tree.getListener(['colors', 'green'])).equal(null);
      expect(tree.children).equal(null);
    });
    it('deletes listener at root', function() {
      var tree = new EventMapTree();
      var listener = {};
      tree.setListener([], listener);
      expect(tree.getListener([])).equal(listener);
      var previous = tree.deleteListener([]);
      expect(previous).equal(listener);
      expect(tree.getListener([])).equal(null);
    });
    it('deletes listener at subpath', function() {
      var tree = new EventMapTree();
      var listener = {};
      tree.setListener(['colors', 'green'], listener);
      expect(tree.getListener(['colors', 'green'])).equal(listener);
      var previous = tree.deleteListener(['colors', 'green']);
      expect(previous).equal(listener);
      expect(tree.children).equal(null);
    });
    it('deletes listener with remaining children', function() {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      tree.setListener(['colors'], listener1);
      tree.setListener(['colors', 'green'], listener2);
      expect(tree.getListener(['colors'])).equal(listener1);
      expect(tree.getListener(['colors', 'green'])).equal(listener2);
      tree.deleteListener(['colors']);
      expect(tree.getListener(['colors'])).equal(null);
      expect(tree.getListener(['colors', 'green'])).equal(listener2);
    });
    it('deletes listener with remaining peers', function() {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      tree.setListener(['colors', 'red'], listener1);
      tree.setListener(['colors', 'green'], listener2);
      expect(tree.getListener(['colors', 'red'])).equal(listener1);
      expect(tree.getListener(['colors', 'green'])).equal(listener2);
      tree.deleteListener(['colors', 'red']);
      expect(tree.getListener(['colors', 'red'])).equal(null);
      expect(tree.getListener(['colors', 'green'])).equal(listener2);
    });
  });
  describe('deleteAllListeners', function() {
    it('can be called on empty root', function() {
      var tree = new EventMapTree();
      tree.deleteAllListeners([]);
    });
    it('can be called on missing node', function() {
      var tree = new EventMapTree();
      tree.deleteAllListeners(['colors', 'green']);
    });
    it('deletes all listeners and children when called on root', function() {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      var listener3 = 'listener3';
      tree.setListener([], listener1);
      tree.setListener(['colors'], listener2);
      tree.setListener(['colors', 'green'], listener3);
      tree.deleteAllListeners([]);
      expect(tree.getListener([])).equal(null);
      expect(tree.children).equal(null);
    });
    it('deletes listeners and descendent children on path', function() {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      var listener3 = 'listener3';
      tree.setListener([], listener1);
      tree.setListener(['colors'], listener2);
      tree.setListener(['colors', 'green'], listener3);
      tree.deleteAllListeners(['colors']);
      expect(tree.getListener([])).equal(listener1);
      expect(tree.children).equal(null);
    });
  });
  describe('getAffectedListeners', function() {
    it('returns empty array without listeners', function() {
      var tree = new EventMapTree();
      var affected = tree.getAffectedListeners([]);
      expect(affected).eql([]);
    });
    it('returns empty array on path without node', function() {
      var tree = new EventMapTree();
      var affected = tree.getAffectedListeners(['colors', 'green']);
      expect(affected).eql([]);
    });
    it('returns all direct listeners', function() {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      tree.setListener([], listener1);
      var affected = tree.getAffectedListeners([]);
      expect(affected).eql([listener1]);
    });
    it('deleteListener stops listener from being returned', function() {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      tree.setListener([], listener1);
      tree.deleteListener([], listener1);
      var affected = tree.getAffectedListeners([]);
      expect(affected).eql([]);
    });
    it('returns all descendant listeners', function() {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      var listener3 = 'listener3';
      var listener4 = 'listener4';
      tree.setListener(['colors', 'green'], listener1);
      tree.setListener(['colors', 'red'], listener2);
      tree.setListener([], listener3);
      tree.setListener(['colors'], listener4);
      var affected = tree.getAffectedListeners([]);
      expect(affected).eql([listener3, listener4, listener1, listener2]);
    });
    it('returns all parent listeners in depth order', function() {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      var listener3 = 'listener3';
      var listener4 = 'listener4';
      tree.setListener(['colors', 'green'], listener1);
      tree.setListener(['colors', 'red'], listener2);
      tree.setListener([], listener3);
      tree.setListener(['colors'], listener4);
      var affected = tree.getAffectedListeners(['colors', 'green']);
      expect(affected).eql([listener3, listener4, listener1]);
    });
    it('does not return peers or peer children', function() {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      var listener3 = 'listener3';
      var listener4 = 'listener4';
      var listener5 = 'listener5';
      tree.setListener([], listener1);
      tree.setListener(['colors'], listener2);
      tree.setListener(['colors', 'green'], listener3);
      tree.setListener(['textures'], listener4);
      tree.setListener(['textures', 'smooth'], listener5);
      var affected = tree.getAffectedListeners(['textures']);
      expect(affected).eql([listener1, listener4, listener5]);
    });
  });
  describe('forEach', function() {
    it('can be called on empty tree', function() {
      var tree = new EventMapTree();
      tree.forEach(function() {
        throw new Error('Unexpected call');
      });
    });
    it('calls back with direct listener', function(done) {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      tree.setListener([], listener1);
      tree.forEach(function(listener) {
        expect(listener).equal(listener1);
        done();
      });
    });
    it('calls back with each descendant listener', function(done) {
      var tree = new EventMapTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      var listener3 = 'listener3';
      tree.setListener(['colors'], listener1);
      tree.setListener(['colors', 'green'], listener2);
      tree.setListener(['colors', 'red'], listener3);
      var expected = [listener1, listener2, listener3];
      tree.forEach(function(listener) {
        expect(listener).equal(expected.shift());
        if (expected.length === 0) done();
      });
    });
  });
});
