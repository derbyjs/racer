var expect = require('../util').expect;
var util = require('../../lib/util');

describe('util', function() {
  describe('util.mergeInto', function() {
    it('merges empty objects', function() {
      var a = {};
      var b = {};
      expect(util.mergeInto(a, b)).to.eql({});
    });

    it('merges an empty object with a populated object', function() {
      var fn = function(x) {
        return x++;
      };
      var a = {};
      var b = {x: 's', y: [1, 3], fn: fn};
      expect(util.mergeInto(a, b)).to.eql({x: 's', y: [1, 3], fn: fn});
    });

    it('merges a populated object with a populated object', function() {
      var fn = function(x) {
        return x++;
      };
      var a = {x: 's', y: [1, 3], fn: fn};
      var b = {x: 7, z: {}};
      expect(util.mergeInto(a, b)).to.eql({x: 7, y: [1, 3], fn: fn, z: {}});
      // Merge should modify the first argument
      expect(a).to.eql({x: 7, y: [1, 3], fn: fn, z: {}});
      // But not the second
      expect(b).to.eql({x: 7, z: {}});
    });
  });

  describe('promisify', function() {
    it('wrapped functions return promise', async function() {
      var targetFn = function(num, cb) {
        setImmediate(function() {
          cb(undefined, num);
        });
      };
      var promisedFn = util.promisify(targetFn);
      var promise = promisedFn(3);
      expect(promise).to.be.instanceOf(Promise);
      var result = await promise;
      expect(result).to.equal(3);
    });

    it('wrapped functions throw errors passed to callback', async function() {
      var targetFn = function(num, cb) {
        setImmediate(function() {
          cb(new Error(`Error ${num}`));
        });
      };
      var promisedFn = util.promisify(targetFn);
      try {
        await promisedFn(3);
        fail('Expected promisedFn to reject, but it successfully resolved');
      } catch (error) {
        expect(error).to.have.property('message', 'Error 3');
      }
    });

    it('wrapped functions throw on thrown error', async function() {
      var targetFn = function(num) {
        throw new Error(`Error ${num}`);
      };
      var promisedFn = util.promisify(targetFn);
      try {
        await promisedFn(3);
        fail('Expected promisedFn to reject, but it successfully resolved');
      } catch (error) {
        expect(error).to.have.property('message', 'Error 3');
      }
    });
  });
});
