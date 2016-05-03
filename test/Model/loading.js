var expect = require('../util').expect;
var racer = require('../../lib/index');

describe('loading', function() {
  describe('subscribe', function() {
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
});
