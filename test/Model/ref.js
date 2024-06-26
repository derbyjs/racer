var expect = require('../util').expect;
var RootModel = require('../../lib/Model').RootModel;

describe('ref', function() {
  function expectEvents(pattern, model, done, events) {
    model.on('all', pattern, function() {
      events.shift().apply(null, arguments);
      if (!events.length) done();
    });
    if (!events || !events.length) done();
  }
  describe('event emission', function() {
    it('re-emits on a reffed path', function(done) {
      var model = new RootModel();
      model.ref('_page.color', '_page.colors.green');
      model.on('change', '_page.color', function(value) {
        expect(value).to.equal('#0f0');
        done();
      });
      model.set('_page.colors.green', '#0f0');
    });
    it('also emits on the original path', function(done) {
      var model = new RootModel();
      model.ref('_page.color', '_page.colors.green');
      model.on('change', '_page.colors.green', function(value) {
        expect(value).to.equal('#0f0');
        done();
      });
      model.set('_page.colors.green', '#0f0');
    });
    it('re-emits on a child of a reffed path', function(done) {
      var model = new RootModel();
      model.ref('_page.color', '_page.colors.green');
      model.on('change', '_page.color.*', function(capture, value) {
        expect(capture).to.equal('hex');
        expect(value).to.equal('#0f0');
        done();
      });
      model.set('_page.colors.green.hex', '#0f0');
    });
    it('re-emits when a parent is changed', function(done) {
      var model = new RootModel();
      model.ref('_page.color', '_page.colors.green');
      model.on('change', '_page.color', function(value) {
        expect(value).to.equal('#0e0');
        done();
      });
      model.set('_page.colors', {
        green: '#0e0'
      });
    });
    it('re-emits on a ref to a ref', function(done) {
      var model = new RootModel();
      model.ref('_page.myFavorite', '_page.color');
      model.ref('_page.color', '_page.colors.green');
      model.on('change', '_page.myFavorite', function(value) {
        expect(value).to.equal('#0f0');
        done();
      });
      model.set('_page.colors.green', '#0f0');
    });
    it('re-emits on multiple reffed paths', function(done) {
      var model = new RootModel();
      model.set('_page.colors.green', '#0f0');
      model.ref('_page.favorites.my', '_page.colors.green');
      model.ref('_page.favorites.your', '_page.colors.green');
      expectEvents('_page.favorites**', model, done, [
        function(capture, method, value) {
          expect(method).to.equal('change');
          expect(capture).to.equal('my');
          expect(value).to.equal('#0f1');
        }, function(capture, method, value) {
          expect(method).to.equal('change');
          expect(capture).to.equal('your');
          expect(value).to.equal('#0f1');
        }
      ]);
      model.set('_page.colors.green', '#0f1');
    });
  });
  describe('get', function() {
    it('gets from a reffed path', function() {
      var model = new RootModel();
      model.set('_page.colors.green', '#0f0');
      expect(model.get('_page.color')).to.equal(undefined);
      model.ref('_page.color', '_page.colors.green');
      expect(model.get('_page.color')).to.equal('#0f0');
    });
    it('gets from a child of a reffed path', function() {
      var model = new RootModel();
      model.set('_page.colors.green.hex', '#0f0');
      model.ref('_page.color', '_page.colors.green');
      expect(model.get('_page.color')).to.eql({
        hex: '#0f0'
      });
      expect(model.get('_page.color.hex')).to.equal('#0f0');
    });
    it('gets from a ref to a ref', function() {
      var model = new RootModel();
      model.ref('_page.myFavorite', '_page.color');
      model.ref('_page.color', '_page.colors.green');
      model.set('_page.colors.green', '#0f0');
      expect(model.get('_page.myFavorite')).to.equal('#0f0');
    });
  });
  describe('event/add ordering', function() {
    it('ref results are propogated when set in reponse to an event', function() {
      var model = new RootModel();
      model.on('change', '_page.start', function() {
        model.ref('_page.myColor', '_page.color');
        model.ref('_page.yourColor', '_page.color');
        model.set('_page.yourColor', 'green');
      });
      model.set('_page.start', true);
      expect(model.get('_page.color')).to.equal('green');
      expect(model.get('_page.myColor')).to.equal('green');
    });
    it('can create refList in event callback', function() {
      var model = new RootModel();
      model.on('change', '_page.start', function() {
        model.set('_page.colors', {
          red: '#f00',
          green: '#0f0',
          blue: '#00f'
        });
        model.set('_page.ids', ['blue', 'green']);
        model.refList('_page.list', '_page.colors', '_page.ids');
      });
      model.set('_page.start', true);
      expect(model.get('_page.list')).to.eql(['#00f', '#0f0']);
    });
    it('removing ref on same toPath in event callback is ok', function() {
      // The effects of listeners are synchronous, so while fanning out the refs
      // for a given toPath - "_page.color" in this case - it's possible for one
      // of the refs to be removed. Modifying during iteration can cause issues
      // if not handled correctly.
      var model = new RootModel();
      model.ref('_page.ref1', '_page.color');
      model.ref('_page.ref2', '_page.color');
      model.set('_page.color', 'red');
      model.once('change', '_page.ref1', function() {
        model.removeRef('_page.ref2');
      });

      model.set('_page.color', 'green');
      expect(model.get('_page.ref1')).to.eql('green');
      // ref2 was removed while processing ref, but it should still be updated
      // for this current change.
      expect(model.get('_page.ref2')).to.eql('green');

      // ref2 is now removed, so it should no longer be updated.
      model.set('_page.color', 'blue');
      expect(model.get('_page.ref1')).to.eql('blue');
      expect(model.get('_page.ref2')).to.eql('green');
    });
  });
  describe('updateIndices option', function() {
    it('updates a ref when an array insert happens at the `to` path', function() {
      var model = new RootModel();
      model.set('_page.colors', ['red', 'green', 'blue']);
      model.ref('_page.color', '_page.colors.1', {updateIndices: true});
      expect(model.get('_page.color')).to.equal('green');
      model.unshift('_page.colors', 'yellow');
      expect(model.get('_page.color')).to.equal('green');
      model.push('_page.colors', 'orange');
      expect(model.get('_page.color')).to.equal('green');
      model.insert('_page.colors', 2, ['purple', 'cyan']);
      expect(model.get('_page.color')).to.equal('green');
    });
    it('updates a ref when an array remove happens at the `to` path', function() {
      var model = new RootModel();
      model.set('_page.colors', ['red', 'blue', 'purple', 'cyan', 'green', 'yellow']);
      model.ref('_page.color', '_page.colors.4', {updateIndices: true});
      expect(model.get('_page.color')).to.equal('green');
      model.shift('_page.colors');
      expect(model.get('_page.color')).to.equal('green');
      model.pop('_page.colors');
      expect(model.get('_page.color')).to.equal('green');
      model.remove('_page.colors', 1, 2);
      expect(model.get('_page.color')).to.equal('green');
    });
    it('updates a ref when an array move happens at the `to` path', function() {
      var model = new RootModel();
      model.set('_page.colors', ['red', 'blue', 'purple', 'green', 'cyan', 'yellow']);
      model.ref('_page.color', '_page.colors.3', {updateIndices: true});
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
      expect(model.get('_page.color')).to.equal('green');
    });
    it('updates a ref when an array insert happens within the `to` path', function() {
      var model = new RootModel();
      model.set('_page.colors', [
        {name: 'red'},
        {name: 'green'},
        {name: 'blue'}
      ]);
      model.ref('_page.color', '_page.colors.1.name', {updateIndices: true});
      expect(model.get('_page.color')).to.equal('green');
      model.unshift('_page.colors', 'yellow');
      expect(model.get('_page.color')).to.equal('green');
      model.push('_page.colors', 'orange');
      expect(model.get('_page.color')).to.equal('green');
      model.insert('_page.colors', 2, ['purple', 'cyan']);
      expect(model.get('_page.color')).to.equal('green');
    });
    it('updates a ref when an array remove happens within the `to` path', function() {
      var model = new RootModel();
      model.set('_page.colors', [
        {name: 'red'},
        {name: 'blue'},
        {name: 'purple'},
        {name: 'cyan'},
        {name: 'green'},
        {name: 'yellow'}
      ]);
      model.ref('_page.color', '_page.colors.4.name', {updateIndices: true});
      expect(model.get('_page.color')).to.equal('green');
      model.shift('_page.colors');
      expect(model.get('_page.color')).to.equal('green');
      model.pop('_page.colors');
      expect(model.get('_page.color')).to.equal('green');
      model.remove('_page.colors', 1, 2);
      expect(model.get('_page.color')).to.equal('green');
    });
    it('updates a ref when an array move happens within the `to` path', function() {
      var model = new RootModel();
      model.set('_page.colors', [
        {name: 'red'},
        {name: 'blue'},
        {name: 'purple'},
        {name: 'green'},
        {name: 'cyan'},
        {name: 'yellow'}
      ]);
      model.ref('_page.color', '_page.colors.3.name', {updateIndices: true});
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
      expect(model.get('_page.color')).to.equal('green');
    });
  });
});
