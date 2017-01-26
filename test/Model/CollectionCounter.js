var expect = require('../util').expect;
var CollectionCounter = require('../../lib/Model/CollectionCounter');

describe('CollectionCounter', function() {
  var cc = new CollectionCounter();

  it('increment', function() {
    expect(cc.toJSON()).to.be(undefined);
    expect(cc.get('numbers', 'one')).to.be(undefined);
    expect(cc.increment('numbers', 'one')).to.equal(1);    
    expect(cc.increment('numbers', 'one')).to.equal(2);    
  });
  it('toJSON', function() {
    expect(cc.toJSON()).to.eql({
      numbers: {
        one: 2
      }
    });
  });
  it('decrement', function() {
    expect(cc.get('numbers', 'one')).to.equal(2);    

    expect(cc.decrement('numbers', 'one')).to.equal(1);
    expect(cc.decrement('numbers', 'one')).to.equal(0);    

    expect(cc.get('numbers', 'one')).to.be(undefined);
    expect(cc.toJSON()).to.be(undefined);
  });
});
