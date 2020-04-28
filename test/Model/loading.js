var expect = require('../util').expect;
var racer = require('../../lib/index');

describe('loading', function() {
  beforeEach(function(done) {
    this.backend = racer.createBackend();
    // Add a delay on all messages to help catch race issues
    var delay = 5;
    this.backend.use('receive', function(request, next) {
      delay++;
      setTimeout(next, delay);
    });
    this.model = this.backend.createModel();
    this.model.connection.on('connected', done);
  });

  describe('subscribe', function() {
    it('calls back simultaneous subscribes to the same document', function(done) {
      var doc = this.model.connection.get('colors', 'green');
      expect(doc.version).equal(null);

      var calls = 0;
      var cb = function(err) {
        if (err) return done(err);
        expect(doc.version).equal(0);
        calls++;
      };
      for (var i = 3; i--;) {
        this.model.subscribe('colors.green', cb);
      }

      this.model.whenNothingPending(function() {
        expect(calls).equal(3);
        done();
      });
    });

    it('calls back when doc is already subscribed', function(done) {
      var model = this.model;
      var doc = model.connection.get('colors', 'green');
      model.subscribe('colors.green', function(err) {
        if (err) return done(err);
        expect(doc.subscribed).equal(true);
        model.subscribe('colors.green', done);
      });
    });
  });

  describe('unfetch deferred unload', function() {
    beforeEach(function(done) {
      this.setupModel = this.backend.createModel();
      this.setupModel.add('colors', {id: 'green', hex: '00ff00'}, done);
    });

    it('unloads doc after Share doc has nothing pending', function(done) {
      var model = this.model;
      model.fetch('colors.green', function(err) {
        if (err) return done(err);
        expect(model.get('colors.green.hex')).to.equal('00ff00');
        // Queue up a pending op.
        model.set('colors.green.hex', '00ee00');
        // Unfetch. This triggers the delayed _maybeUnloadDoc.
        // The pending op causes the doc unload to be delayed.
        model.unfetch('colors.green');
        // Once there's nothing pending on the model/doc...
        model.whenNothingPending(function() {
          // Racer doc should be unloaded.
          expect(model.get('colors.green')).to.equal(undefined);
          // Share doc should be unloaded too.
          expect(model.connection.getExisting('colors', 'green')).to.equal(undefined);
          done();
        });
      });
    });

    it('does not unload doc if a subscribe is issued in the meantime', function(done) {
      var model = this.model;
      // Racer keeps its own reference counts of doc fetches/subscribes - see `_hasDocReferences`.
      model.fetch('colors.green', function(err) {
        if (err) return done(err);
        expect(model.get('colors.green.hex')).to.equal('00ff00');
        // Queue up a pending op.
        model.set('colors.green.hex', '00ee00');
        // Unfetch. This triggers the delayed _maybeUnloadDoc.
        // The pending op causes the doc unload to be delayed.
        model.unfetch('colors.green');
        // Immediately subscribe to the same doc.
        // This causes the doc to be kept in memory, even after the unfetch completes.
        model.subscribe('colors.green');
        // Once there's nothing pending on the model/doc...
        model.whenNothingPending(function() {
          // Racer doc should still be present due to the subscription.
          expect(model.get('colors.green')).to.eql({id: 'green', hex: '00ee00'});
          // Share doc should be present too.
          var shareDoc = model.connection.getExisting('colors', 'green');
          expect(shareDoc).to.have.property('data');
          expect(shareDoc.data).to.eql({id: 'green', hex: '00ee00'});
          done();
        });
      });
    });
  });
});
