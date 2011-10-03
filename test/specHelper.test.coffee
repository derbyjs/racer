should = require 'should'
specHelper = require 'specHelper'

module.exports =
  'test specHelper.isArray': ->
    specHelper.isArray([]).should.eql true
    specHelper.isArray(specHelper.create []).should.eql true

    specHelper.isArray(null).should.eql false
    specHelper.isArray(undefined).should.eql false
    specHelper.isArray({}).should.eql false
    specHelper.isArray(1).should.eql false
    specHelper.isArray('hi').should.eql false
    specHelper.isArray(true).should.eql false

    specHelper.isArray(specHelper.create null).should.eql false
    specHelper.isArray(specHelper.create {}).should.eql false
