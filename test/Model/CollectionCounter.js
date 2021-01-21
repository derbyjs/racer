var expect = require('../util').expect;
var CollectionCounter = require('../../lib/Model/CollectionCounter');

describe('CollectionCounter', function() {
  describe('increment', function() {
    it('increments count for a document', function() {
      var counter = new CollectionCounter();
      expect(counter.get('colors', 'green')).to.equal(0);
      expect(counter.increment('colors', 'green')).to.equal(1);
      expect(counter.increment('colors', 'green')).to.equal(2);
      expect(counter.get('colors', 'green')).to.equal(2);
    });
  });
  describe('decrement', function() {
    it('has no effect on empty collection', function() {
      var counter = new CollectionCounter();
      expect(counter.decrement('colors', 'green')).to.equal(0);
    });
    it('has no effect on empty doc in existing collection', function() {
      var counter = new CollectionCounter();
      expect(counter.increment('colors', 'red'));
      expect(counter.decrement('colors', 'green')).to.equal(0);
    });
    it('decrements count for a document', function() {
      var counter = new CollectionCounter();
      expect(counter.increment('colors', 'green'));
      expect(counter.increment('colors', 'green'));
      expect(counter.decrement('colors', 'green')).to.equal(1);
      expect(counter.decrement('colors', 'green')).to.equal(0);
      expect(counter.get('colors', 'green')).to.equal(0);
    });
    it('does not affect peer document', function() {
      var counter = new CollectionCounter();
      expect(counter.increment('colors', 'green'));
      expect(counter.increment('colors', 'red'));
      expect(counter.decrement('colors', 'green'));
      expect(counter.get('colors', 'green')).to.equal(0);
      expect(counter.get('colors', 'red')).to.equal(1);
    });
    it('does not affect peer collection', function() {
      var counter = new CollectionCounter();
      expect(counter.increment('colors', 'green'));
      expect(counter.increment('textures', 'smooth'));
      expect(counter.decrement('colors', 'green'));
      expect(counter.get('colors', 'green')).to.equal(0);
      expect(counter.get('textures', 'smooth')).to.equal(1);
    });
  });
  describe('toJSON', function() {
    it('returns undefined if there are no counts', function() {
      var counter = new CollectionCounter();
      expect(counter.toJSON()).to.equal(undefined);
    });
    it('returns a nested map representing counts', function() {
      var counter = new CollectionCounter();
      counter.increment('colors', 'green');
      counter.increment('colors', 'green');
      counter.increment('colors', 'red');
      counter.increment('textures', 'smooth');
      expect(counter.toJSON()).to.eql({
        colors: {
          green: 2,
          red: 1
        },
        textures: {
          smooth: 1
        }
      });
    });
    it('incrementing then decrementing returns nothing', function() {
      var counter = new CollectionCounter();
      counter.increment('colors', 'green');
      counter.decrement('colors', 'green');
      expect(counter.toJSON()).to.equal(undefined);
    });
    it('decrementing id from collection with other keys removes key', function() {
      var counter = new CollectionCounter();
      counter.increment('colors', 'green');
      counter.increment('colors', 'red');
      counter.decrement('colors', 'green');
      expect(counter.toJSON()).to.eql({
        colors: {
          red: 1
        }
      });
    });
  });
});
