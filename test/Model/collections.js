const {expect} = require('../util');
const {RootModel} = require('../../lib');

describe('collections', () => {
  describe('getOrDefault', () => {
    it('returns value if defined', () => {
      const model = new RootModel();
      model.add('_test_doc', {name: 'foo'});
      const value = model.getOrDefault('_test_doc', {name: 'bar'});
      expect(value).not.to.be.undefined;
    });

    it('returns defuault value if undefined', () => {
      const model = new RootModel();
      const defaultValue = {name: 'bar'};
      const value = model.getOrDefault('_test_doc', defaultValue);
      expect(value).not.to.be.undefined;
      expect(value.name).to.equal('bar');
      expect(value).to.eql(defaultValue);
    });

    it('returns default value if null', () => {
      const model = new RootModel();
      const id = model.add('_test_doc', {name: null});
      const defaultValue = 'bar';
      const value = model.getOrDefault(`_test_doc.${id}.name`, defaultValue);
      expect(value).not.to.be.null;
      expect(value).to.equal('bar');
      expect(value).to.eql(defaultValue);
    });
  });

  describe('getOrThrow', () => {
    it('returns value if defined', () => {
      const model = new RootModel();
      model.add('_test_doc', {name: 'foo'});
      const value = model.getOrThrow('_test_doc');
      expect(value).not.to.be.undefined;
    });

    it('throws if value undefined', () => {
      const model = new RootModel();
      expect(() => model.getOrThrow('_test_doc')).to.throw(`No value at path _test_doc`);
      expect(() => model.scope('_test').getOrThrow('doc.1')).to.throw(`No value at path _test.doc.1`);
    });

    it('throws if value null', () => {
      const model = new RootModel();
      const id = model.add('_test_doc', {name: null});
      expect(model.getOrThrow(`_test_doc.${id}`)).to.eql({id, name: null});
      expect(() => model.getOrThrow(`_test_doc.${id}.name`)).to.throw(`No value at path _test_doc`);
    });
  });

  describe('getValues', () => {
    it('returns array of values from collection', () => {
      const model = new RootModel();
      model.add('_test_docs', {name: 'foo'});
      model.add('_test_docs', {name: 'bar'});
      const values = model.getValues('_test_docs');
      expect(values).to.be.instanceOf(Array);
      expect(values).to.have.lengthOf(2);
      ['foo', 'bar'].forEach((value, index) => {
        expect(values[index]).to.have.property('name', value);
      });
    });

    it('return empty array when no values at subpath', () => {
      const model = new RootModel();
      const values = model.getValues('_test_docs');
      expect(values).to.be.instanceOf(Array);
      expect(values).to.have.lengthOf(0);
    });

    it('throws error if non-object result at path', () => {
      const model = new RootModel();
      const id = model.add('_colors', {rgb: 3});
      expect(
        () => model.getValues(`_colors.${id}.rgb`)
      ).to.throw(`Found non-object type for getValues('_colors.${id}.rgb')`);
    });
  });
});
