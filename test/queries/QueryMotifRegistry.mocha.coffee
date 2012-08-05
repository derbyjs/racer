QueryMotifRegistry = require '../../lib/descriptor/query/QueryMotifRegistry'
QueryBuilder = require '../../lib/descriptor/query/QueryBuilder'
{expect} = require '../util'

describe 'QueryMotifRegistry', ->
  beforeEach ->
    @registry = new QueryMotifRegistry

  describe 'QueryMotifRegistry.fromJSON', ->
    it 'should be equivalent to the QueryMotifRegistry that generated the json', ->
      ns = 'users'
      queryName = 'withRole'
      cb = (role) ->
        this.where('roles').contains([role])
      @registry.add ns, queryName, cb
      json = @registry.toJSON()
      newReg = QueryMotifRegistry.fromJSON(json)
      expect(@registry).to.deepEql newReg

  describe '#queryTupleBuilder', ->
    it 'should return an Object with methods named after the ns query motifs', ->
      ns = 'users'
      @registry.add ns, 'withRole', (role) ->
        @where('roles').contains([role])
      @registry.add ns, 'female', ->
        @where('gender').equals('female')
      builder = @registry.queryTupleBuilder(ns)
      expect(builder.withRole).to.be.a.function
      expect(builder.female).to.be.a.function

    it 'should return an Object that does not include methods named after ns query motifs that were removed via QueryMotifRegistry#remove', ->
      ns = 'users'
      @registry.add ns, 'withRole', (role) ->
        @where('roles').contains([role])
      @registry.add ns, 'female', ->
        @where('gender').equals('female')
      @registry.remove ns, 'withRole'
      builder = @registry.queryTupleBuilder(ns)
      expect(builder.withRole).to.not.be.ok()
      expect(builder.female).to.be.a.function

    it 'should return an Object whose methods are chainable', ->
      ns = 'users'
      @registry.add ns, 'withRole', (role) ->
        @where('roles').contains([role])
      @registry.add ns, 'female', ->
        @where('gender').equals('female')
      builder = @registry.queryTupleBuilder(ns)
      nextBuilder = builder.withRole('admin').female()
      expect(nextBuilder).to.equal builder

    it 'should return an Object that builds up a correct query tuple', ->
      ns = 'users'
      @registry.add ns, 'withRole', (role) ->
        @where('roles').contains([role])
      @registry.add ns, 'female', ->
        @where('gender').equals('female')
      builder = @registry.queryTupleBuilder(ns)
      builder.withRole('admin').female()
      expect(builder.tuple).to.eql [ns, {withRole: ['admin'], female: []}, null]

  describe '#queryJSON', ->
    it 'should return a JSON representation of the query', ->
      @registry.add 'users', 'withRole', (role) ->
        @where('roles').contains([role])
      json = @registry.queryJSON(['users', {withRole: ['admin']}])
      expect(json).to.be.an Object
      expect(json).to.eql
        from: 'users'
        contains:
          roles: ['admin']
        type: 'find'

    it 'should return null for query tuples that use unregistered query motifs', ->
      @registry.add 'users', 'female', ->
        @where('gender').equals('female')
      json = @registry.queryJSON(['users', {withRole: ['admin'], female: []}])
      expect(json).to.equal null

    it 'should return null for query tuples that use removed query motifs', ->
      @registry.add 'users', 'withRole', (role) ->
        @where('roles').contains([role])
      @registry.add 'users', 'female', ->
        @where('gender').equals('female')
      @registry.remove 'users', 'withRole'
      json = @registry.queryJSON(['users', {withRole: ['admin'], female: []}])
      expect(json).to.equal null
