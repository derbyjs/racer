MemoryQuery = require '../../lib/descriptor/query/MemoryQuery'
DbMemory = require('../../lib/adapters/db-memory').adapter
expect = require 'expect.js'

describe 'MemoryQuery', ->
  adapter = new DbMemory
  adapter.set 'users.a',
    id: 'a'
    name:
      first: 'John'
      last: 'Doe'
    age: 25

  adapter.set 'users.b',
    id: 'b'
    name:
      first: 'Betty'
      last: 'Crocker'
    age: 50

  adapter.set 'users.c'
    id: 'c'
    name:
      first: 'Sherlock'
      last: 'Holmes'
    age: 23

  adapter.set 'users.d'
    id: 'd'
    name:
      first: 'James'
      last: 'Watson'
    age: 28

  adapter.set 'users.e'
    id: 'e'
    name:
      first: 'James'
      last: 'Watson'
    age: 30

  describe '#run', ->
    it 'should pass back matches', ->
      q = new MemoryQuery
        from: 'users'
        equals: { 'name.first': 'John' }
      q.run adapter, (err, found) ->
        expect(err).to.not.be.ok()
        expect(found).to.have.length(1)

      q = new MemoryQuery
        from: 'users'
        gt: age: 23
      q.run adapter, (err, found) ->
        expect(err).to.not.be.ok()
        expect(found).to.have.length(4)

    it 'should respect `only` simple paths', ->
      q = new MemoryQuery
        from: 'users'
        equals: { 'name.first': 'John' }
        only: {'name': 1}
      q.run adapter, (err, found) ->
        expect(err).to.not.be.ok()
        doc = found[0]
        expect(doc).to.only.have.keys('id', 'name')

    it 'should respect `only` compound paths', ->
      q = new MemoryQuery
        from: 'users'
        equals: { 'name.first': 'John' }
        only: {'name.first': 1}
      q.run adapter, (err, found) ->
        expect(err).to.not.be.ok()
        doc = found[0]
        expect(doc).to.only.have.keys('id', 'name')

    it 'should respect `except`', ->
      q = new MemoryQuery
        from: 'users'
        equals: { 'name.first': 'John' }
        except: { 'name.last': 1, age: 1 }
      q.run adapter, (err, found) ->
        expect(err).to.not.be.ok()
        doc = found[0]
        expect(doc).to.only.have.keys('id', 'name')
        expect(doc.name).to.only.have.keys('first')

    it 'should throw if you try to exclude "id" via `except`', ->
      fn = ->
        q = new MemoryQuery
          from: 'users'
          equals: { 'name.first': 'John' }
          except: { 'name.last': 1, age: 1, id: 1}
      expect(fn).to.throwException 'You cannot ignore `id`'

    it 'should do simple sorts', ->
      q = new MemoryQuery
        from: 'users'
        gt: { age: 0 }
        sort: ['name.last', 'asc']
      q.run adapter, (err, found) ->
        expect(err).to.not.be.ok()
        expect(found[0].id).to.equal('b')
        expect(found[1].id).to.equal('a')
        expect(found[2].id).to.equal('c')
        expect(found[3].id).to.equal('d')
        expect(found[4].id).to.equal('e')

    it 'should do compound sorts', ->
      q = new MemoryQuery
        from: 'users'
        gt: { age: 0 }
        sort: ['name.last', 'asc', 'age', 'desc']
      q.run adapter, (err, found) ->
        expect(err).to.not.be.ok()
        expect(found[0].id).to.equal('b')
        expect(found[1].id).to.equal('a')
        expect(found[2].id).to.equal('c')
        expect(found[3].id).to.equal('e')
        expect(found[4].id).to.equal('d')

    it 'should handle skip/limit', ->
      q = new MemoryQuery
        from: 'users'
        gt: { age: 0 }
        sort: ['name.last', 'asc', 'age', 'desc']
        skip: 2
        limit: 2
      q.run adapter, (err, found) ->
        expect(err).to.not.be.ok()
        expect(found).to.have.length(2)
        expect(found[0].id).to.equal('c')
        expect(found[1].id).to.equal('e')
      q = new MemoryQuery
        from: 'users'
        gt: { age: 0 }
        sort: ['name.last', 'asc', 'age', 'desc']
        skip: 0
        limit: 3
      q.run adapter, (err, found) ->
        expect(err).to.not.be.ok()
        expect(found).to.have.length(3)
        expect(found[0].id).to.equal('b')
        expect(found[1].id).to.equal('a')
        expect(found[2].id).to.equal('c')
