var Model, expect;

expect = require('../util').expect;

Model = require('../../lib/Model');

describe('path', function() {
  describe('ats', function() {
    return it('sets the initial value to empty array if no inputs', function() {
      var model;
      var ats;
      model = (new Model).at('_page');
      model.set('list', ['a', 'b', 'c']);
      ats = model.ats('list');
      expect(ats[0].path()).to.eql('_page.list.0');
      expect(ats[1].path()).to.eql('_page.list.1');
      return expect(ats[2].path()).to.eql('_page.list.2');
    });
  });
});
