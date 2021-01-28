var expect = require('../util').expect;
var racer = require('../../lib/index');

describe('Model events without useEventObjects', function() {
  describe('mutator events', function() {
    it('calls earlier listeners in the order of mutations', function(done) {
      var model = (new racer.Model()).at('_page');
      var expectedPaths = ['a', 'b', 'c'];
      model.on('change', '**', function(path) {
        expect(path).to.equal(expectedPaths.shift());
        if (!expectedPaths.length) {
          done();
        }
      });
      model.on('change', 'a', function() {
        model.set('b', 2);
      });
      model.on('change', 'b', function() {
        model.set('c', 3);
      });
      model.set('a', 1);
    });

    it('calls later listeners in the order of mutations', function(done) {
      var model = (new racer.Model()).at('_page');
      model.on('change', 'a', function() {
        model.set('b', 2);
      });
      model.on('change', 'b', function() {
        model.set('c', 3);
      });
      var expectedPaths = ['a', 'b', 'c'];
      model.on('change', '**', function(path) {
        expect(path).to.equal(expectedPaths.shift());
        if (!expectedPaths.length) {
          done();
        }
      });
      model.set('a', 1);
    });

    it('can omit the path argument', function(done) {
      var model = (new racer.Model()).at('_page');

      model.at('a').on('change', function(value, prev) {
        expect(value).to.equal(1);
        expect(prev).not.to.exist;
        done();
      });
      model.set('a', 1);
    });
  });

  describe('remote events', function() {
    beforeEach(function(done) {
      var backend = racer.createBackend();
      var local = this.local = backend.createModel().scope('colors.green');
      var remote = this.remote = backend.createModel().scope('colors.green');
      local.create(function(err) {
        if (err) return done(err);
        remote.subscribe(done);
      });
    });

    describe('set', function() {
      it('can raise events registered on array indices', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        this.remote.on('change', 'array.0', function(value, previous) {
          expect(value).to.equal(1);
          expect(previous).to.equal(0);
          done();
        });
        this.local.set('array.0', 1);
      });
    });

    describe('move', function() {
      it('can move an item from the end to the beginning of the array', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4]);
        this.remote.on('move', '**', function(captures, from, to) {
          expect(from).to.equal(4);
          expect(to).to.equal(0);
          done();
        });
        this.local.move('array', 4, 0, 1);
      });
      it('can swap the first two items in the array', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        this.remote.on('move', '**', function(captures, from, to) {
          expect(from).to.equal(1);
          expect(to).to.equal(0);
          done();
        });
        this.local.move('array', 1, 0, 1, function() {});
      });
      it('can move an item from the begnning to the end of the array', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        this.remote.on('move', '**', function(captures, from, to) {
          expect(from).to.equal(0);
          expect(to).to.equal(4);
          done();
        });
        this.local.move('array', 0, 4, 1, function() {});
      });
      it('supports a negative destination index of -1 (for last)', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        this.remote.on('move', '**', function(captures, from, to) {
          expect(from).to.equal(0);
          expect(to).to.equal(4);
          done();
        });
        this.local.move('array', 0, -1, 1, function() {});
      });
      it('supports a negative source index of -1 (for last)', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        this.remote.on('move', '**', function(captures, from, to) {
          expect(from).to.equal(4);
          expect(to).to.equal(2);
          done();
        });
        this.local.move('array', -1, 2, 1, function() {});
      });
      it('can move several items mid-array, with an event for each', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        var events = 0;
        this.remote.on('move', '**', function(captures, from, to) {
          expect(from).to.equal(1);
          expect(to).to.equal(4);
          if (++events === 2) {
            done();
          }
        });
        this.local.move('array', 1, 3, 2, function() {});
      });
    });
  });
});

describe('Model events with {useEventObjects: true}', function() {
  describe('mutator events', function() {
    it('calls earlier listeners in the order of mutations', function(done) {
      var model = (new racer.Model()).at('_page');
      var expectedPaths = ['a', 'b', 'c'];
      model.on('change', '**', {useEventObjects: true}, function(_event, captures) {
        expect(captures).to.eql([expectedPaths.shift()]);
        if (!expectedPaths.length) {
          done();
        }
      });
      model.on('change', 'a', function() {
        model.set('b', 2);
      });
      model.on('change', 'b', function() {
        model.set('c', 3);
      });
      model.set('a', 1);
    });

    it('calls later listeners in the order of mutations', function(done) {
      var model = (new racer.Model()).at('_page');
      model.on('change', 'a', function() {
        model.set('b', 2);
      });
      model.on('change', 'b', function() {
        model.set('c', 3);
      });
      var expectedPaths = ['a', 'b', 'c'];
      model.on('change', '**', {useEventObjects: true}, function(_event, captures) {
        expect(captures).to.eql([expectedPaths.shift()]);
        if (!expectedPaths.length) {
          done();
        }
      });
      model.set('a', 1);
    });

    it('can omit the path argument when useEventObjects is true', function(done) {
      var model = (new racer.Model()).at('_page');

      model.at('a').on('change', {useEventObjects: true}, function(_event, captures) {
        expect(_event.value).to.equal(1);
        expect(captures).to.have.length(0);
        done();
      });
      model.set('a', 1);
    });
  });

  describe('insert and remove', function() {
    var model;
    before('set up', function() {
      model = (new racer.Model()).at('_page');
    });

    it('insert has expected properties', function(done) {
      model.on('insert', '**', {useEventObjects: true}, function(_event, captures) {
        expect(_event.type).to.equal('insert');
        expect(_event.index).to.equal(2);
        expect(_event.values).to.eql([3]);
        expect(_event.passed).to.eql({});
        expect(captures).to.eql(['a']);
        done();
      });
      model.set('a', [1, 2]);
      model.insert('a', 2, [3]);
    });

    it('remove has expected properties', function(done) {
      model.on('remove', '**', {useEventObjects: true}, function(_event, captures) {
        expect(_event.type).to.equal('remove');
        expect(_event.index).to.equal(2);
        expect(_event.removed).to.eql([3]);
        expect(_event.values).to.eql([3]);
        expect(_event.passed).to.eql({});
        expect(captures).to.eql(['a']);
        done();
      });
      model.pop('a');
    });
  });

  describe('load and unload', function() {
    var local, remote;

    before('set up', function() {
      var backend = racer.createBackend();
      local = backend.createModel().scope('colors.green');
      remote = backend.createModel().scope('colors.green');
    });

    it('load has expected properties', function(done) {
      remote.on('load', '**', {useEventObjects: true}, function(event, captures) {
        expect(event.type).to.equal('load');
        expect(event.value).to.eql({id: 'green'});
        expect(event.document).to.eql({id: 'green'});
        expect(event.passed).to.eql({'$remote': true});
        expect(captures).to.eql(['']);
        done();
      });

      local.create(function() {
        remote.subscribe();
      });
    });

    it('unload has expected properties', function(done) {
      remote.on('unload', '**', {useEventObjects: true}, function(event, captures) {
        expect(event.type).to.equal('unload');
        expect(event.previous).to.eql({id: 'green'});
        expect(event.previousDocument).to.eql({id: 'green'});
        expect(event.passed).to.eql({});
        expect(captures).to.eql(['']);
        done();
      });
      remote.unsubscribe();
    });
  });

  describe('remote events', function() {
    beforeEach(function(done) {
      var backend = racer.createBackend();
      var local = this.local = backend.createModel().scope('colors.green');
      var remote = this.remote = backend.createModel().scope('colors.green');

      local.create(function(err) {
        if (err) return done(err);
        remote.subscribe(done);
      });
    });

    describe('set', function() {
      it('can raise events registered on array indices', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        this.remote.on('change', 'array.0', {useEventObjects: true}, function(event) {
          expect(event.value).to.equal(1);
          expect(event.previous).to.equal(0);
          done();
        });
        this.local.set('array.0', 1);
      });
    });

    describe('move', function() {
      it('can move an item from the end to the beginning of the array', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4]);
        this.remote.on('move', '**', {useEventObjects: true}, function(event) {
          expect(event.from).to.equal(4);
          expect(event.to).to.equal(0);
          expect(event.howMany).to.equal(1);
          done();
        });
        this.local.move('array', 4, 0, 1);
      });

      it('can swap the first two items in the array', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        this.remote.on('move', '**', {useEventObjects: true}, function(event) {
          expect(event.from).to.equal(1);
          expect(event.to).to.equal(0);
          expect(event.howMany).to.equal(1);
          done();
        });
        this.local.move('array', 1, 0, 1, function() {});
      });

      it('can move an item from the begnning to the end of the array', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        this.remote.on('move', '**', {useEventObjects: true}, function(event) {
          expect(event.from).to.equal(0);
          expect(event.to).to.equal(4);
          expect(event.howMany).to.equal(1);
          done();
        });
        this.local.move('array', 0, 4, 1, function() {});
      });

      it('supports a negative destination index of -1 (for last)', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        this.remote.on('move', '**', {useEventObjects: true}, function(event) {
          expect(event.from).to.equal(0);
          expect(event.to).to.equal(4);
          expect(event.howMany).to.equal(1);
          done();
        });
        this.local.move('array', 0, -1, 1, function() {});
      });

      it('supports a negative source index of -1 (for last)', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        this.remote.on('move', '**', {useEventObjects: true}, function(event) {
          expect(event.from).to.equal(4);
          expect(event.to).to.equal(2);
          expect(event.howMany).to.equal(1);
          done();
        });
        this.local.move('array', -1, 2, 1, function() {});
      });

      it('can move several items mid-array, with an event for each', function(done) {
        this.local.set('array', [0, 1, 2, 3, 4], function() {});
        var events = 0;
        this.remote.on('move', '**', {useEventObjects: true}, function(event) {
          expect(event.from).to.equal(1);
          expect(event.to).to.equal(4);
          expect(event.howMany).to.equal(1);
          if (++events === 2) {
            done();
          }
        });
        this.local.move('array', 1, 3, 2, function() {});
      });
    });
  });
});
