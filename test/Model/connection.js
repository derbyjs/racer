var expect = require('../util').expect;
var racer = require('../../lib/index');

describe('connection', function() {
  describe('getAgent', function() {
    it('returns a reference to the ShareDB agent on the server', function() {
      var backend = racer.createBackend();
      var model = backend.createModel();
      var agent = model.getAgent();
      expect(agent).ok();
    });

    it('returns null once the model is disconnected', function(done) {
      var backend = racer.createBackend();
      var model = backend.createModel();
      model.close(function() {
        var agent = model.getAgent();
        expect(agent).equal(null);
        done();
      });
    });
  });
});
