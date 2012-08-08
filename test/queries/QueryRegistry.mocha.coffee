QueryRegistry = require '../../lib/descriptor/query/QueryRegistry'
{expect} = require '../util'

describe 'QueryRegistry', ->
  beforeEach ->
    @registry = new QueryRegistry

  describe '#lookup', ->
    it 'should be able to find a query that was added', ->
      ns = 'users'
      @registry.add [ns, {withRole: ['admin']}]
      {id, tuple, tags} = @registry.lookup [ns,{withRole: ['admin']}]
      expect(id).to.equal '_1'
      expect(tuple).to.eql [ns, {withRole: ['admin']}, null, '_1']
      expect(tags).to.eql []

    it 'should not find a query that was not added', ->
      ns = 'users'
      result = @registry.lookup [ns,{withRole: ['admin']}]
      expect(result).to.be.null

    it 'should not find a query that was added and then removed', ->
      ns = 'users'
      @registry.add [ns, {withRole: ['admin']}]
      @registry.remove [ns, {withRole: ['admin']}]
      result = @registry.lookup [ns,{withRole: ['admin']}]
      expect(result).to.be.null

  describe '#queryId', ->
    it 'should return the queryId for a registered query tuple', ->
      ns = 'users'
      @registry.add [ns, {withRole: ['admin']}]
      queryId = @registry.queryId [ns, {withRole: ['admin']}]
      expect(queryId).to.equal '_1'

  describe 'QueryRegistry.fromJSON', ->
    it 'should be equivalent to the QueryRegistry that generated the json', ->
      ns = 'users'
      @registry.add [ns, {withRole: ['admin']}]
      json = @registry.toJSON()
      newReg = QueryRegistry.fromJSON(json)
      expect(@registry).to.deepEql newReg

  describe '#memoryQuery', ->
    it 'should lazily generate the MemoryQuery', ->

  describe '#lookupWithTag', ->
    it 'should return query tuples that have been tagged', ->
      ns = 'users'
      @registry.add [ns, {withRole: ['admin']}]
      @registry.tag '_1', 'subs'
      results = @registry.lookupWithTag 'subs'
      expect(results).to.eql [
        [ns, {withRole: ['admin']}, null, '_1']
      ]

    it 'should not return query tuples that have not been tagged', ->
      ns = 'users'
      @registry.add [ns, {withRole: ['admin']}]
      results = @registry.lookupWithTag 'subs'
      expect(results).to.eql []

    it 'should not return query tuples that were tagged and then untagged', ->
      ns = 'users'
      @registry.add [ns, {withRole: ['admin']}]
      @registry.tag '_1', 'subs'
      @registry.untag '_1', 'subs'
      results = @registry.lookupWithTag 'subs'
      expect(results).to.eql []
