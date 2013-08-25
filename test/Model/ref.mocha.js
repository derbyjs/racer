var Model, expect;

expect = require('../util').expect;

Model = require('../../lib/Model');

describe('ref', function() {
  var expectEvents;
  expectEvents = function(pattern, model, done, events) {
    model.on('all', pattern, function() {
      events.shift().apply(null, arguments);
      if (!events.length) {
        return done();
      }
    });
    if (!(events != null ? events.length : void 0)) {
      return done();
    }
  };
  describe('event emission', function() {
    it('re-emits on a reffed path', function(done) {
      var model;
      model = new Model;
      model.ref('_page.color', '_page.colors.green');
      model.on('change', '_page.color', function(value) {
        expect(value).to.equal('#0f0');
        return done();
      });
      return model.set('_page.colors.green', '#0f0');
    });
    it('also emits on the original path', function(done) {
      var model;
      model = new Model;
      model.ref('_page.color', '_page.colors.green');
      model.on('change', '_page.colors.green', function(value) {
        expect(value).to.equal('#0f0');
        return done();
      });
      return model.set('_page.colors.green', '#0f0');
    });
    it('re-emits on a child of a reffed path', function(done) {
      var model;
      model = new Model;
      model.ref('_page.color', '_page.colors.green');
      model.on('change', '_page.color.*', function(capture, value) {
        expect(capture).to.equal('hex');
        expect(value).to.equal('#0f0');
        return done();
      });
      return model.set('_page.colors.green.hex', '#0f0');
    });
    it('re-emits when a parent is changed', function(done) {
      var model;
      model = new Model;
      model.ref('_page.color', '_page.colors.green');
      model.on('change', '_page.color', function(value) {
        expect(value).to.equal('#0e0');
        return done();
      });
      return model.set('_page.colors', {
        green: '#0e0'
      });
    });
    it('re-emits on a ref to a ref', function(done) {
      var model;
      model = new Model;
      model.ref('_page.myFavorite', '_page.color');
      model.ref('_page.color', '_page.colors.green');
      model.on('change', '_page.myFavorite', function(value) {
        expect(value).to.equal('#0f0');
        return done();
      });
      return model.set('_page.colors.green', '#0f0');
    });
    return it('re-emits on multiple reffed paths', function(done) {
      var model;
      model = new Model;
      model.set('_page.colors.green', '#0f0');
      model.ref('_page.favorites.my', '_page.colors.green');
      model.ref('_page.favorites.your', '_page.colors.green');
      expectEvents('_page.favorites**', model, done, [
        function(capture, method, value, previous) {
          expect(method).to.equal('change');
          expect(capture).to.equal('my');
          return expect(value).to.equal('#0f1');
        }, function(capture, method, value, previous) {
          expect(method).to.equal('change');
          expect(capture).to.equal('your');
          return expect(value).to.equal('#0f1');
        }
      ]);
      return model.set('_page.colors.green', '#0f1');
    });
  });
  describe('get', function() {
    it('gets from a reffed path', function() {
      var model;
      model = new Model;
      model.set('_page.colors.green', '#0f0');
      expect(model.get('_page.color')).to.equal(void 0);
      model.ref('_page.color', '_page.colors.green');
      return expect(model.get('_page.color')).to.equal('#0f0');
    });
    it('gets from a child of a reffed path', function() {
      var model;
      model = new Model;
      model.set('_page.colors.green.hex', '#0f0');
      model.ref('_page.color', '_page.colors.green');
      expect(model.get('_page.color')).to.eql({
        hex: '#0f0'
      });
      return expect(model.get('_page.color.hex')).to.equal('#0f0');
    });
    return it('gets from a ref to a ref', function() {
      var model;
      model = new Model;
      model.ref('_page.myFavorite', '_page.color');
      model.ref('_page.color', '_page.colors.green');
      model.set('_page.colors.green', '#0f0');
      return expect(model.get('_page.myFavorite')).to.equal('#0f0');
    });
  });
  describe('dereference', function() {
    it('normal dereference', function() {
      var model;
      model = new Model;
      model.set('_page.colors.green', '#0f0');
      expect(model.get('_page.color')).to.equal(void 0);
      var ref = model.ref('_page.color', '_page.colors.green');
      return expect(ref.dereference()).to.equal('_page.colors.green');
    });
    it('dereference with forArrayMutator using internal call', function() {
      var model;
      model = new Model;
      model.setEach('_page.colors', {
          green: {color: '#0f0', id: 'green'}
        , blue: {color: '#f00', id: 'blue'}
        , red: {color: '#00f', id: 'red'}
        , lilac: {color: '#ff0', id: 'lilac'}
        , purple: {color: '#0ff', id: 'purple'}
        , marine: {color: '#f0f', id: 'marine'}
        , white: {color: '#fff', id: 'white'}
        , black: {color: '#000', id: 'black'}
      });
      model.set('_page.ids', ['green', 'lilac', 'marine']);
      model.refList('_page.filteredColors', '_page.colors', '_page.ids');
      expect(model.get('_page.filteredColors')[0]).to.equal(model.get('_page.colors')['green']);
      expect(model.get('_page.filteredColors')[1]).to.equal(model.get('_page.colors')['lilac']);
      expect(model.get('_page.filteredColors')[2]).to.equal(model.get('_page.colors')['marine']);
      expect(model._dereference('_page.filteredColors.0'.split('.'), true).join('.')).to.equal('_page.colors.green');
      expect(model._dereference('_page.filteredColors.1'.split('.'), true).join('.')).to.equal('_page.colors.lilac');
      expect(model._dereference('_page.filteredColors.2'.split('.'), true).join('.')).to.equal('_page.colors.marine');
    });
    return it('dereference with forArrayMutator using external call', function() {
      var model;
      model = new Model;
      model.setEach('_page.colors', {
          green: {color: '#0f0', id: 'green'}
        , blue: {color: '#f00', id: 'blue'}
        , red: {color: '#00f', id: 'red'}
        , lilac: {color: '#ff0', id: 'lilac'}
        , purple: {color: '#0ff', id: 'purple'}
        , marine: {color: '#f0f', id: 'marine'}
        , white: {color: '#fff', id: 'white'}
        , black: {color: '#000', id: 'black'}
      });
      model.set('_page.ids', ['green', 'lilac', 'marine']);
      model.refList('_page.filteredColors', '_page.colors', '_page.ids');
      expect(model.get('_page.filteredColors')[0]).to.equal(model.get('_page.colors')['green']);
      expect(model.get('_page.filteredColors')[1]).to.equal(model.get('_page.colors')['lilac']);
      expect(model.get('_page.filteredColors')[2]).to.equal(model.get('_page.colors')['marine']);
      expect(model.dereference('_page.filteredColors.0', true)).to.equal('_page.colors.green');
      expect(model.dereference('_page.filteredColors.1', true)).to.equal('_page.colors.lilac');
      expect(model.dereference('_page.filteredColors.2', true)).to.equal('_page.colors.marine');
    });
  });
  return describe('updateIndices option', function() {
    it('updates a ref when an array insert happens at the `to` path', function() {
      var model;
      model = new Model;
      model.set('_page.colors', ['red', 'green', 'blue']);
      model.ref('_page.color', '_page.colors.1', {
        updateIndices: true
      });
      expect(model.get('_page.color')).to.equal('green');
      model.unshift('_page.colors', 'yellow');
      expect(model.get('_page.color')).to.equal('green');
      model.push('_page.colors', 'orange');
      expect(model.get('_page.color')).to.equal('green');
      model.insert('_page.colors', 2, ['purple', 'cyan']);
      return expect(model.get('_page.color')).to.equal('green');
    });
    it('updates a ref when an array remove happens at the `to` path', function() {
      var model;
      model = new Model;
      model.set('_page.colors', ['red', 'blue', 'purple', 'cyan', 'green', 'yellow']);
      model.ref('_page.color', '_page.colors.4', {
        updateIndices: true
      });
      expect(model.get('_page.color')).to.equal('green');
      model.shift('_page.colors');
      expect(model.get('_page.color')).to.equal('green');
      model.pop('_page.colors');
      expect(model.get('_page.color')).to.equal('green');
      model.remove('_page.colors', 1, 2);
      return expect(model.get('_page.color')).to.equal('green');
    });
    it('updates a ref when an array move happens at the `to` path', function() {
      var model;
      model = new Model;
      model.set('_page.colors', ['red', 'blue', 'purple', 'green', 'cyan', 'yellow']);
      model.ref('_page.color', '_page.colors.3', {
        updateIndices: true
      });
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 0, 1);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 4, 5);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 0, 5);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 1, 3);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 0, 3, 2);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 2, 3, 2);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 3, 2, 2);
      return expect(model.get('_page.color')).to.equal('green');
    });
    it('updates a ref when an array insert happens within the `to` path', function() {
      var model;
      model = new Model;
      model.set('_page.colors', [
        {
          name: 'red'
        }, {
          name: 'green'
        }, {
          name: 'blue'
        }
      ]);
      model.ref('_page.color', '_page.colors.1.name', {
        updateIndices: true
      });
      expect(model.get('_page.color')).to.equal('green');
      model.unshift('_page.colors', 'yellow');
      expect(model.get('_page.color')).to.equal('green');
      model.push('_page.colors', 'orange');
      expect(model.get('_page.color')).to.equal('green');
      model.insert('_page.colors', 2, ['purple', 'cyan']);
      return expect(model.get('_page.color')).to.equal('green');
    });
    it('updates a ref when an array remove happens within the `to` path', function() {
      var model;
      model = new Model;
      model.set('_page.colors', [
        {
          name: 'red'
        }, {
          name: 'blue'
        }, {
          name: 'purple'
        }, {
          name: 'cyan'
        }, {
          name: 'green'
        }, {
          name: 'yellow'
        }
      ]);
      model.ref('_page.color', '_page.colors.4.name', {
        updateIndices: true
      });
      expect(model.get('_page.color')).to.equal('green');
      model.shift('_page.colors');
      expect(model.get('_page.color')).to.equal('green');
      model.pop('_page.colors');
      expect(model.get('_page.color')).to.equal('green');
      model.remove('_page.colors', 1, 2);
      return expect(model.get('_page.color')).to.equal('green');
    });
    return it('updates a ref when an array move happens within the `to` path', function() {
      var model;
      model = new Model;
      model.set('_page.colors', [
        {
          name: 'red'
        }, {
          name: 'blue'
        }, {
          name: 'purple'
        }, {
          name: 'green'
        }, {
          name: 'cyan'
        }, {
          name: 'yellow'
        }
      ]);
      model.ref('_page.color', '_page.colors.3.name', {
        updateIndices: true
      });
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 0, 1);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 4, 5);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 0, 5);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 1, 3);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 0, 3, 2);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 2, 3, 2);
      expect(model.get('_page.color')).to.equal('green');
      model.move('_page.colors', 3, 2, 2);
      return expect(model.get('_page.color')).to.equal('green');
    });
  });
});
