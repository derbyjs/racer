var expect = require('../util').expect;
var EventListenerTree = require('../../lib/Model/EventListenerTree');

describe('EventListenerTree', function() {
  describe('implementation', function() {
    describe('constructor', function() {
      it('creates an empty tree', function() {
        var tree = new EventListenerTree();
        expect(tree.listeners).equal(null);
        expect(tree.children).equal(null);
      });
    });
    describe('addListener', function() {
      it('adds a listener object at the root', function() {
        var tree = new EventListenerTree();
        var listener = {};
        tree.addListener([], listener);
        expect(tree.listeners).eql([listener]);
        expect(tree.children).eql(null);
      });
      it('only a listener object once', function() {
        var tree = new EventListenerTree();
        var listener = {};
        tree.addListener([], listener);
        tree.addListener([], listener);
        expect(tree.listeners).eql([listener]);
        expect(tree.children).eql(null);
      });
      it('adds a listener object at a path', function() {
        var tree = new EventListenerTree();
        var listener = {};
        tree.addListener(['colors'], listener);
        expect(tree.listeners).eql(null);
        expect(tree.children.colors.listeners).eql([listener]);
      });
      it('adds a listener object at a subpath', function() {
        var tree = new EventListenerTree();
        var listener = {};
        tree.addListener(['colors', 'green'], listener);
        expect(tree.listeners).eql(null);
        expect(tree.children.colors.listeners).eql(null);
        expect(tree.children.colors.children.green.listeners).eql([listener]);
      });
    });
    describe('removeListener', function() {
      it('can be called before addListener', function() {
        var tree = new EventListenerTree();
        var listener = {};
        tree.removeListener([], listener);
        expect(tree.listeners).eql(null);
        expect(tree.children).eql(null);
      });
      it('removes listener at root', function() {
        var tree = new EventListenerTree();
        var listener = {};
        tree.addListener([], listener);
        expect(tree.listeners).eql([listener]);
        tree.removeListener([], listener);
        expect(tree.listeners).eql(null);
      });
      it('removes listener at subpath', function() {
        var tree = new EventListenerTree();
        var listener = {};
        tree.addListener(['colors', 'green'], listener);
        expect(tree.children.colors.children.green.listeners).eql([listener]);
        tree.removeListener(['colors', 'green'], listener);
        expect(tree.children).eql(null);
      });
      it('removes listener with remaining peers', function() {
        var tree = new EventListenerTree();
        var listener1 = 'listener1';
        var listener2 = 'listener2';
        var listener3 = 'listener3';
        tree.addListener([], listener1);
        tree.addListener([], listener2);
        tree.addListener([], listener3);
        expect(tree.listeners).eql([listener1, listener2, listener3]);
        tree.removeListener([], listener2);
        expect(tree.listeners).eql([listener1, listener3]);
        tree.removeListener([], listener3);
        expect(tree.listeners).eql([listener1]);
        tree.removeListener([], listener1);
        expect(tree.listeners).eql(null);
      });
      it('removes listener with remaining peer children', function() {
        var tree = new EventListenerTree();
        var listener1 = 'listener1';
        var listener2 = 'listener2';
        tree.addListener(['colors'], listener1);
        tree.addListener(['colors', 'green'], listener2);
        expect(tree.children.colors.listeners).eql([listener1]);
        expect(tree.children.colors.children.green.listeners).eql([listener2]);
        tree.removeListener(['colors'], listener1);
        expect(tree.children.colors.listeners).eql(null);
        expect(tree.children.colors.children.green.listeners).eql([listener2]);
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
        var listener1 = 'listener1';
        var listener2 = 'listener2';
        var listener3 = 'listener3';
        tree.addListener([], listener1);
        tree.addListener(['colors'], listener2);
        tree.addListener(['colors', 'green'], listener3);
        tree.removeAllListeners([]);
        expect(tree.listeners).eql(null);
        expect(tree.children).eql(null);
      });
      it('removes listeners and descendent children on path', function() {
        var tree = new EventListenerTree();
        var listener1 = 'listener1';
        var listener2 = 'listener2';
        var listener3 = 'listener3';
        tree.addListener([], listener1);
        tree.addListener(['colors'], listener2);
        tree.addListener(['colors', 'green'], listener3);
        tree.removeAllListeners(['colors']);
        expect(tree.listeners).eql([listener1]);
        expect(tree.children).eql(null);
      });
    });
  });
  describe('forEachAffected', function() {
    function expectResults(expected, done) {
      var pending = expected.slice();
      return function(result) {
        var value = pending.shift();
        expect(value).eql(result);
        if (pending.length > 0) return;
        done();
      };
    }
    it('can be called without listeners', function(done) {
      var tree = new EventListenerTree();
      tree.forEachAffected([], done);
      done();
    });
    it('calls a callback with all direct listeners', function(done) {
      var tree = new EventListenerTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      tree.addListener([], listener1);
      tree.addListener([], listener2);
      var callback = expectResults([listener1, listener2], done);
      tree.forEachAffected([], callback);
    });
    it('removeListener stops listener from being returned', function(done) {
      var tree = new EventListenerTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      tree.addListener([], listener1);
      tree.addListener([], listener2);
      tree.removeListener([], listener1);
      var callback = expectResults([listener2], done);
      tree.forEachAffected([], callback);
    });
    it('calls a callback with all descendant listeners in depth order', function(done) {
      var tree = new EventListenerTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      var listener3 = 'listener3';
      var listener4 = 'listener4';
      var listener5 = 'listener5';
      tree.addListener(['colors', 'green'], listener1);
      tree.addListener(['colors', 'red'], listener2);
      tree.addListener(['colors', 'red'], listener3);
      tree.addListener([], listener4);
      tree.addListener(['colors'], listener5);
      var callback = expectResults([listener4, listener5, listener1, listener2, listener3], done);
      tree.forEachAffected([], callback);
    });
    it('calls a callback with all parent listeners in depth order', function(done) {
      var tree = new EventListenerTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      var listener3 = 'listener3';
      var listener4 = 'listener4';
      var listener5 = 'listener5';
      tree.addListener(['colors', 'green'], listener1);
      tree.addListener(['colors', 'red'], listener2);
      tree.addListener(['colors', 'red'], listener3);
      tree.addListener([], listener4);
      tree.addListener(['colors'], listener5);
      var callback = expectResults([listener4, listener5, listener1], done);
      tree.forEachAffected(['colors', 'green'], callback);
    });
    it('does not call for peers or peer children', function(done) {
      var tree = new EventListenerTree();
      var listener1 = 'listener1';
      var listener2 = 'listener2';
      var listener3 = 'listener3';
      var listener4 = 'listener4';
      var listener5 = 'listener5';
      tree.addListener([], listener1);
      tree.addListener(['colors'], listener2);
      tree.addListener(['colors', 'green'], listener3);
      tree.addListener(['textures'], listener4);
      tree.addListener(['textures', 'smooth'], listener5);
      var callback = expectResults([listener1, listener4, listener5], done);
      tree.forEachAffected(['textures'], callback);
    });
  });
});
