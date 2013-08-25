var Model, expect,
  __slice = [].slice;

expect = require('../util').expect;

Model = require('../../lib/Model');

describe('fn', function() {
  describe('evaluate', function() {
    it('supports fn with a getter function', function() {
      var model, result;
      model = new Model;
      model.fn('sum', function(a, b) {
        return a + b;
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      result = model.evaluate('sum', '_nums.a', '_nums.b');
      return expect(result).to.equal(6);
    });
    it('supports fn with an object', function() {
      var model, result;
      model = new Model;
      model.fn('sum', {
        get: function(a, b) {
          return a + b;
        }
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      result = model.evaluate('sum', '_nums.a', '_nums.b');
      return expect(result).to.equal(6);
    });
    it('supports fn with variable arguments', function() {
      var model, result;
      model = new Model;
      model.fn('sum', function() {
        var arg, args, sum, _i, _len;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        sum = 0;
        for (_i = 0, _len = args.length; _i < _len; _i++) {
          arg = args[_i];
          sum += arg;
        }
        return sum;
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      model.set('_nums.c', 7);
      result = model.evaluate('sum', '_nums.a', '_nums.b', '_nums.c');
      return expect(result).to.equal(13);
    });
    return it('supports scoped model paths', function() {
      var $nums, model, result;
      model = new Model;
      model.fn('sum', function(a, b) {
        return a + b;
      });
      $nums = model.at('_nums');
      $nums.set('a', 2);
      $nums.set('b', 4);
      result = model.evaluate('sum', '_nums.a', '_nums.b');
      expect(result).to.equal(6);
      result = $nums.evaluate('sum', 'a', 'b');
      return expect(result).to.equal(6);
    });
  });
  describe('start and stop with getter', function() {
    it('sets the output immediately on start', function() {
      var model, value;
      model = new Model;
      model.fn('sum', function(a, b) {
        return a + b;
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      value = model.start('sum', '_nums.sum', '_nums.a', '_nums.b');
      expect(value).to.equal(6);
      return expect(model.get('_nums.sum')).to.equal(6);
    });
    it('sets the output when an input changes', function() {
      var model;
      model = new Model;
      model.fn('sum', function(a, b) {
        return a + b;
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      model.start('sum', '_nums.sum', '_nums.a', '_nums.b');
      expect(model.get('_nums.sum')).to.equal(6);
      model.set('_nums.a', 5);
      return expect(model.get('_nums.sum')).to.equal(9);
    });
    it('sets the output when a parent of the input changes', function() {
      var model;
      model = new Model;
      model.fn('sum', function(a, b) {
        return a + b;
      });
      model.set('_nums.in', {
        a: 2,
        b: 4
      });
      model.start('sum', '_nums.sum', '_nums.in.a', '_nums.in.b');
      expect(model.get('_nums.sum')).to.equal(6);
      model.set('_nums.in', {
        a: 5,
        b: 7
      });
      return expect(model.get('_nums.sum')).to.equal(12);
    });
    it('does not set the output when a sibling of the input changes', function() {
      var count, model;
      model = new Model;
      count = 0;
      model.fn('sum', function(a, b) {
        count++;
        return a + b;
      });
      model.set('_nums.in', {
        a: 2,
        b: 4
      });
      model.start('sum', '_nums.sum', '_nums.in.a', '_nums.in.b');
      expect(model.get('_nums.sum')).to.equal(6);
      expect(count).to.equal(1);
      model.set('_nums.in.a', 3);
      expect(model.get('_nums.sum')).to.equal(7);
      expect(count).to.equal(2);
      model.set('_nums.in.c', -1);
      expect(model.get('_nums.sum')).to.equal(7);
      return expect(count).to.equal(2);
    });
    it('can call stop without start', function() {
      var model;
      model = new Model;
      return model.stop('_nums.sum');
    });
    return it('stops updating after calling stop', function() {
      var model;
      model = new Model;
      model.fn('sum', function(a, b) {
        return a + b;
      });
      model.set('_nums.a', 2);
      model.set('_nums.b', 4);
      model.start('sum', '_nums.sum', '_nums.a', '_nums.b');
      model.set('_nums.a', 1);
      expect(model.get('_nums.sum')).to.equal(5);
      model.stop('_nums.sum');
      model.set('_nums.a', 3);
      return expect(model.get('_nums.sum')).to.equal(5);
    });
  });
  describe('setter', function() {
    return it('sets the input when the output changes', function() {
      var model;
      model = new Model;
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
      model.at('_user.name').start('fullName', 'full', 'first', 'last');
      expect(model.get('_user.name')).to.eql({
        first: 'John',
        last: 'Smith',
        full: 'John Smith'
      });
      model.set('_user.name.full', 'Jane Doe');
      return expect(model.get('_user.name')).to.eql({
        first: 'Jane',
        last: 'Doe',
        full: 'Jane Doe'
      });
    });
  });
  return describe('event mirroring', function() {
    it('emits move event on output when input changes', function(done) {
      var model;
      model = new Model;
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
      model.start('unity', '_test.out', '_test.in');
      model.on('all', '_test.out**', function(path, event) {
        expect(event).to.equal('move');
        expect(path).to.equal('a');
        return done();
      });
      model.move('_test.in.a', 0, 1);
      return expect(model.get('_test.out')).to.eql(model.get('_test.in'));
    });
    it('emits move event on input when output changes', function(done) {
      var model;
      model = new Model;
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
      model.start('unity', '_test.out', '_test.in');
      model.on('all', '_test.in**', function(path, event) {
        expect(event).to.equal('move');
        expect(path).to.equal('a');
        return done();
      });
      model.move('_test.out.a', 0, 1);
      return expect(model.get('_test.out')).to.eql(model.get('_test.in'));
    });
    it('emits granular change event under an array when input changes', function(done) {
      var model;
      model = new Model;
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
      model.start('unity', '_test.out', '_test.in');
      model.on('all', '_test.out**', function(path, event) {
        expect(event).to.equal('change');
        expect(path).to.equal('a.0.x');
        return done();
      });
      model.set('_test.in.a.0.x', 3);
      return expect(model.get('_test.out')).to.eql(model.get('_test.in'));
    });
    return it('emits granular change event under an array when output changes', function(done) {
      var model;
      model = new Model;
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
      model.start('unity', '_test.out', '_test.in');
      model.on('all', '_test.in**', function(path, event) {
        expect(event).to.equal('change');
        expect(path).to.equal('a.0.x');
        return done();
      });
      model.set('_test.out.a.0.x', 3);
      return expect(model.get('_test.out')).to.eql(model.get('_test.in'));
    });
  });
});
