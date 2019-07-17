var expect = require('../util').expect;
var CollectionCounter = require('../../lib/Model/CollectionCounter');

describe('CollectionCounter', function() {
  it('increment', function() {
    var counter = new CollectionCounter();
    expect(counter.get('colors', 'green')).to.be(undefined);
    expect(counter.increment('colors', 'green')).to.equal(1);
    expect(counter.increment('colors', 'green')).to.equal(2);
    expect(counter.get('colors', 'green')).to.equal(2);
  });

  it('toJSON', function() {
    var counter = new CollectionCounter();
    expect(counter.toJSON()).to.be(undefined);
    expect(counter.increment('colors', 'green')).to.equal(1);
    expect(counter.increment('colors', 'green')).to.equal(2);
    expect(counter.toJSON()).to.eql({
      colors: {
        green: 2
      }
    });
  });

  it('decrement', function() {
    var counter = new CollectionCounter();
    expect(counter.increment('colors', 'green'));
    expect(counter.increment('colors', 'green'));

    expect(counter.decrement('colors', 'green')).to.equal(1);
    expect(counter.decrement('colors', 'green')).to.equal(0);

    expect(counter.get('colors', 'green')).to.be(undefined);
    expect(counter.toJSON()).to.be(undefined);
  });
});
