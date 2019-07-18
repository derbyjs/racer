var expect = require('../util').expect;
var Model = require('../../lib/Model');

['setDiff', 'setDiffDeep', 'setArrayDiff', 'setArrayDiffDeep'].forEach(function(method) {
  describe(method + ' common diff functionality', function() {
    it('sets the value when undefined', function() {
      var model = new Model();
      model[method]('_page.color', 'green');
      expect(model.get('_page.color')).to.equal('green');
    });

    it('changes the value', function() {
      var model = new Model();
      model.set('_page.color', 'green');
      model[method]('_page.color', 'red');
      expect(model.get('_page.color')).to.equal('red');
    });

    it('changes an object', function() {
      var model = new Model();
      model.set('_page.color', {hex: '#0f0', name: 'green'});
      model[method]('_page.color', {hex: '#f00', name: 'red'});
      expect(model.get('_page.color')).to.eql({hex: '#f00', name: 'red'});
    });

    it('deletes keys from an object', function() {
      var model = new Model();
      model.set('_page.color', {hex: '#0f0', name: 'green'});
      model[method]('_page.color', {name: 'green'});
      expect(model.get('_page.color')).to.eql({name: 'green'});
    });

    it('adds items to an array', function() {
      var model = new Model();
      model.set('_page.items', [4]);
      model[method]('_page.items', [2, 3, 4]);
      expect(model.get('_page.items')).to.eql([2, 3, 4]);
    });

    it('removes items in an array', function() {
      var model = new Model();
      model.set('_page.items', [2, 3, 4]);
      model[method]('_page.items', [3, 4]);
      expect(model.get('_page.items')).to.eql([3, 4]);
    });

    it('moves items in an array', function() {
      var model = new Model();
      model.set('_page.items', [2, 3, 4]);
      model[method]('_page.items', [3, 4, 2]);
      expect(model.get('_page.items')).to.eql([3, 4, 2]);
    });

    it('adds items to an array in an object', function() {
      var model = new Model();
      model.set('_page.lists', {a: [4]});
      model[method]('_page.lists', {a: [2, 3, 4]});
      expect(model.get('_page.lists')).to.eql({a: [2, 3, 4]});
    });

    it('emits an event when changing value', function(done) {
      var model = new Model();
      model.on('all', function(segments, eventArgs) {
        var type = eventArgs[0];
        var value = eventArgs[1];
        var previous = eventArgs[2];
        expect(segments).eql(['_page', 'color']);
        expect(type).equal('change');
        expect(value).equal('green');
        expect(previous).equal(undefined);
        done();
      });
      model[method]('_page.color', 'green');
    });

    it('does not emit an event when value is not changed', function(done) {
      var model = new Model();
      model.set('_page.color', 'green');
      model.on('all', function() {
        done(new Error('unexpected event emission'));
      });
      model[method]('_page.color', 'green');
      done();
    });
  });
});

describe('setDiff', function() {
  it('emits an event when an object is set to an equivalent object', function(done) {
    var model = new Model();
    model.set('_page.color', {name: 'green'});
    model.on('all', function(segments, eventArgs) {
      var type = eventArgs[0];
      var value = eventArgs[1];
      var previous = eventArgs[2];
      expect(segments).eql(['_page', 'color']);
      expect(type).equal('change');
      expect(value).eql({name: 'green'});
      expect(previous).eql({name: 'green'});
      done();
    });
    model.setDiff('_page.color', {name: 'green'});
  });

  it('emits an event when an array is set to an equivalent array', function(done) {
    var model = new Model();
    model.set('_page.list', [2, 3, 4]);
    model.on('all', function(segments, eventArgs) {
      var type = eventArgs[0];
      var value = eventArgs[1];
      var previous = eventArgs[2];
      expect(segments).eql(['_page', 'list']);
      expect(type).equal('change');
      expect(value).eql([2, 3, 4]);
      expect(previous).eql([2, 3, 4]);
      done();
    });
    model.setDiff('_page.list', [2, 3, 4]);
  });
});

describe('setDiffDeep', function() {
  it('does not emit an event when an object is set to an equivalent object', function(done) {
    var model = new Model();
    model.set('_page.color', {name: 'green'});
    model.on('all', function() {
      done(new Error('unexpected event emission'));
    });
    model.setDiffDeep('_page.color', {name: 'green'});
    done();
  });

  it('does not emit an event when an array is set to an equivalent array', function(done) {
    var model = new Model();
    model.set('_page.list', [2, 3, 4]);
    model.on('all', function() {
      done(new Error('unexpected event emission'));
    });
    model.setDiffDeep('_page.list', [2, 3, 4]);
    done();
  });

  it('does not emit an event when a deep object / array is set to an equivalent value', function(done) {
    var model = new Model();
    model.set('_page.lists', {a: [2, 3], b: [1], _meta: {foo: 'bar'}});
    model.on('all', function() {
      done(new Error('unexpected event emission'));
    });
    model.setDiffDeep('_page.lists', {a: [2, 3], b: [1], _meta: {foo: 'bar'}});
    done();
  });

  it('equivalent objects ignore key order', function(done) {
    var model = new Model();
    model.set('_page.lists', {a: [2, 3], b: [1]});
    model.on('all', function() {
      done(new Error('unexpected event emission'));
    });
    model.setDiffDeep('_page.lists', {b: [1], a: [2, 3]});
    done();
  });

  it('adds items to an array', function(done) {
    var model = new Model();
    model.set('_page.items', [4]);
    model.on('all', function(segments, eventArgs) {
      var type = eventArgs[0];
      var index = eventArgs[1];
      var values = eventArgs[2];
      expect(segments).eql(['_page', 'items']);
      expect(type).equal('insert');
      expect(values).eql([2, 3]);
      expect(index).eql(0);
      done();
    });
    model.setDiffDeep('_page.items', [2, 3, 4]);
  });

  it('adds items to an array in an object', function(done) {
    var model = new Model();
    model.set('_page.lists', {a: [4]});
    model.on('all', function(segments, eventArgs) {
      var type = eventArgs[0];
      var index = eventArgs[1];
      var values = eventArgs[2];
      expect(segments).eql(['_page', 'lists', 'a']);
      expect(type).equal('insert');
      expect(values).eql([2, 3]);
      expect(index).eql(0);
      done();
    });
    model.setDiffDeep('_page.lists', {a: [2, 3, 4]});
  });

  it('emits a delete event when a key is removed from an object', function(done) {
    var model = new Model();
    model.set('_page.color', {hex: '#0f0', name: 'green'});
    model.on('all', function(segments, eventArgs) {
      var type = eventArgs[0];
      var value = eventArgs[1];
      var previous = eventArgs[2];
      expect(segments).eql(['_page', 'color', 'hex']);
      expect(type).equal('change');
      expect(value).equal(undefined);
      expect(previous).equal('#0f0');
      done();
    });
    model.setDiffDeep('_page.color', {name: 'green'});
    expect(model.get('_page.color')).to.eql({name: 'green'});
  });
});

describe('setArrayDiff', function() {
  it('does not emit an event when an array is set to an equivalent array', function(done) {
    var model = new Model();
    model.set('_page.list', [2, 3, 4]);
    model.on('all', function() {
      done(new Error('unexpected event emission'));
    });
    model.setArrayDiff('_page.list', [2, 3, 4]);
    done();
  });

  it('emits an event when objects in an array are set to an equivalent array', function(done) {
    var model = new Model();
    model.set('_page.list', [{a: 2}, {c: 3}, {b: 4}]);
    var expectedEvents = ['remove', 'insert'];
    model.on('all', function(segments, eventArgs) {
      expect(segments).eql(['_page', 'list']);
      var type = eventArgs[0];
      var index = eventArgs[1];
      var values = eventArgs[2];
      var expected = expectedEvents.shift();
      expect(type).equal(expected);
      expect(values).eql([{a: 2}, {c: 3}, {b: 4}]);
      expect(index).eql(0);
      if (expectedEvents.length === 0) done();
    });
    model.setArrayDiff('_page.list', [{a: 2}, {c: 3}, {b: 4}]);
  });
});

describe('setArrayDiffDeep', function() {
  it('does not emit an event when an array is set to an equivalent array', function(done) {
    var model = new Model();
    model.set('_page.list', [2, 3, 4]);
    model.on('all', function() {
      done(new Error('unexpected event emission'));
    });
    model.setArrayDiffDeep('_page.list', [2, 3, 4]);
    done();
  });

  it('does not emit an event when objects in an array are set to an equivalent array', function(done) {
    var model = new Model();
    model.set('_page.list', [{a: 2}, {c: 3}, {b: 4}]);
    model.on('all', function() {
      done(new Error('unexpected event emission'));
    });
    model.setArrayDiffDeep('_page.list', [{a: 2}, {c: 3}, {b: 4}]);
    done();
  });
});
