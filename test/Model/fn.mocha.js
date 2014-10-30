var expect = require('../util').expect;
var Model = require('../../lib/Model');

describe('fn', function() {
  describe('evaluate', function() {
    it('supports fn with a getter function', function() {
      var model = new Model();
      model.fn('sum', function(a, b) {
        return a + b;
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      var result = model.evaluate('_nums.a', '_nums.b', 'sum');
      expect(result).to.equal(6);
    });
    it('supports fn with an object', function() {
      var model = new Model();
      model.fn('sum', {
        get: function(a, b) {
          return a + b;
        }
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      var result = model.evaluate('_nums.a', '_nums.b', 'sum');
      expect(result).to.equal(6);
    });
    it('supports fn with variable arguments', function() {
      var model = new Model();
      model.fn('sum', function() {
        var sum = 0;
        var i = arguments.length;
        while (i--) {
          sum += arguments[i];
        }
        return sum;
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      model.set('_nums.c', 7);
      var result = model.evaluate('_nums.a', '_nums.b', '_nums.c', 'sum');
      expect(result).to.equal(13);
    });
    it('supports scoped model paths', function() {
      var model = new Model();
      model.fn('sum', function(a, b) {
        return a + b;
      });
      var $nums = model.at('_nums');
      $nums.set('a', 2);
      $nums.set('b', 4);
      var result = model.evaluate('_nums.a', '_nums.b', 'sum');
      expect(result).to.equal(6);
      result = $nums.evaluate('a', 'b', 'sum');
      expect(result).to.equal(6);
    });
  });
  describe('start and stop with getter', function() {
    it('sets the output immediately on start', function() {
      var model = new Model();
      model.fn('sum', function(a, b) {
        return a + b;
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      var value = model.start('_nums.sum', '_nums.a', '_nums.b', 'sum');
      expect(value).to.equal(6);
      expect(model.get('_nums.sum')).to.equal(6);
    });
    it('sets the output when an input changes', function() {
      var model = new Model();
      model.fn('sum', function(a, b) {
        return a + b;
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      model.start('_nums.sum', '_nums.a', '_nums.b', 'sum');
      expect(model.get('_nums.sum')).to.equal(6);
      model.set('_nums.a', 5);
      expect(model.get('_nums.sum')).to.equal(9);
    });
    it('sets the output when a parent of the input changes', function() {
      var model = new Model();
      model.fn('sum', function(a, b) {
        return a + b;
      });
      model.set('_nums.in', {
        a: 2,
        b: 4
      });
      model.start('_nums.sum', '_nums.in.a', '_nums.in.b', 'sum');
      expect(model.get('_nums.sum')).to.equal(6);
      model.set('_nums.in', {
        a: 5,
        b: 7
      });
      expect(model.get('_nums.sum')).to.equal(12);
    });
    it('does not set the output when a sibling of the input changes', function() {
      var model = new Model();
      var count = 0;
      model.fn('sum', function(a, b) {
        count++;
        return a + b;
      });
      model.set('_nums.in', {
        a: 2,
        b: 4
      });
      model.start('_nums.sum', '_nums.in.a', '_nums.in.b', 'sum');
      expect(model.get('_nums.sum')).to.equal(6);
      expect(count).to.equal(1);
      model.set('_nums.in.a', 3);
      expect(model.get('_nums.sum')).to.equal(7);
      expect(count).to.equal(2);
      model.set('_nums.in.c', -1);
      expect(model.get('_nums.sum')).to.equal(7);
      expect(count).to.equal(2);
    });
    it('can call stop without start', function() {
      var model = new Model();
      model.stop('_nums.sum');
    });
    it('stops updating after calling stop', function() {
      var model = new Model();
      model.fn('sum', function(a, b) {
        return a + b;
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      model.start('_nums.sum', '_nums.a', '_nums.b', 'sum');
      model.set('_nums.a', 1);
      expect(model.get('_nums.sum')).to.equal(5);
      model.stop('_nums.sum');
      model.set('_nums.a', 3);
      expect(model.get('_nums.sum')).to.equal(5);
    });
  });
  describe('setter', function() {
    it('sets the input when the output changes', function() {
      var model = new Model();
      model.fn('fullName', {
        get: function(first, last) {
          return first + ' ' + last;
        },
        set: function(fullName) {
          return fullName.split(' ');
        }
      });
      model.set('_user.name', {
        first: 'John',
        last: 'Smith'
      });
      model.at('_user.name').start('full', 'first', 'last', 'fullName');
      expect(model.get('_user.name')).to.eql({
        first: 'John',
        last: 'Smith',
        full: 'John Smith'
      });
      model.set('_user.name.full', 'Jane Doe');
      expect(model.get('_user.name')).to.eql({
        first: 'Jane',
        last: 'Doe',
        full: 'Jane Doe'
      });
    });
  });
  describe('event mirroring', function() {
    it('emits move event on output when input changes', function(done) {
      var model = new Model();
      model.fn('unity', {
        get: function(value) {
          return value;
        },
        set: function(value) {
          return [value];
        }
      });
      model.set('_test.in', {
        a: [
          {
            x: 1,
            y: 2
          }, {
            x: 2,
            y: 0
          }
        ]
      });
      model.start('_test.out', '_test.in', 'unity');
      model.on('all', '_test.out**', function(path, event) {
        expect(event).to.equal('move');
        expect(path).to.equal('a');
        done();
      });
      model.move('_test.in.a', 0, 1);
      expect(model.get('_test.out')).to.eql(model.get('_test.in'));
    });
    it('emits move event on input when output changes', function(done) {
      var model = new Model();
      model.fn('unity', {
        get: function(value) {
          return value;
        },
        set: function(value) {
          return [value];
        }
      });
      model.set('_test.in', {
        a: [
          {
            x: 1,
            y: 2
          }, {
            x: 2,
            y: 0
          }
        ]
      });
      model.start('_test.out', '_test.in', 'unity');
      model.on('all', '_test.in**', function(path, event) {
        expect(event).to.equal('move');
        expect(path).to.equal('a');
        done();
      });
      model.move('_test.out.a', 0, 1);
      expect(model.get('_test.out')).to.eql(model.get('_test.in'));
    });
    it('emits granular change event under an array when input changes', function(done) {
      var model = new Model();
      model.fn('unity', {
        get: function(value) {
          return value;
        },
        set: function(value) {
          return [value];
        }
      });
      model.set('_test.in', {
        a: [
          {
            x: 1,
            y: 2
          }, {
            x: 2,
            y: 0
          }
        ]
      });
      model.start('_test.out', '_test.in', 'unity');
      model.on('all', '_test.out**', function(path, event) {
        expect(event).to.equal('change');
        expect(path).to.equal('a.0.x');
        done();
      });
      model.set('_test.in.a.0.x', 3);
      expect(model.get('_test.out')).to.eql(model.get('_test.in'));
    });
    it('emits granular change event under an array when output changes', function(done) {
      var model = new Model();
      model.fn('unity', {
        get: function(value) {
          return value;
        },
        set: function(value) {
          return [value];
        }
      });
      model.set('_test.in', {
        a: [
          {
            x: 1,
            y: 2
          }, {
            x: 2,
            y: 0
          }
        ]
      });
      model.start('_test.out', '_test.in', 'unity');
      model.on('all', '_test.in**', function(path, event) {
        expect(event).to.equal('change');
        expect(path).to.equal('a.0.x');
        done();
      });
      model.set('_test.out.a.0.x', 3);
      expect(model.get('_test.out')).to.eql(model.get('_test.in'));
    });
  });
});
