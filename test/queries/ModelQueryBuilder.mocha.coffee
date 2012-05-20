ModelQueryBuilder = require '../../lib/queries/ModelQueryBuilder'
{shouldActLikeQueryBuilder} = require './QueryBuilder.mocha'
expect = require 'expect.js'

describe 'ModelQueryBuilder', ->
  shouldActLikeQueryBuilder(ModelQueryBuilder)()

  describe '#find', ->
    it 'should create and run a MemoryQuery, returning matches syncrhonously'

  describe '#findOne', ->
    it 'should create and run a MemoryQuery, returning a match syncrhonously'
