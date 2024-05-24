const {expect} = require('chai');
const {RootModel} = require('../../lib/Model');

describe('mutators', () => {
  describe('add', () => {
    const guidRegExp = new RegExp(/[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}/);
    it('returns created id in callback', () => {
      const model = new RootModel();
      model.add('_test_doc', {name: 'foo'}, (error, id) => {
        expect(error).to.not.exist;
        expect(id).not.to.be.undefined;
        expect(id).to.match(guidRegExp, 'Expected a GUID-like Id');
      });
    });

    it('resolves promised add with id', async () => {
      const model = new RootModel();
      const id = await model.addPromised('_test_doc', {name: 'bar'});
      expect(id).not.to.be.undefined;
      expect(id).to.match(guidRegExp, 'Expected a GUID-like Id');
    });
  });
});
