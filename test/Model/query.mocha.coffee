{expect} = require '../util'
{BrowserModel} = require '../util/model'
{query} = (new BrowserModel)

describe 'Model.query', ->

  describe 'hashing', ->
    it 'should create the same hash for 2 equivalent queries that exhibit different method call ordering', ->
      q1 = query('users').where('name').equals('brian').where('age').equals(26)
      q2 = query('users').where('age').equals(26).where('name').equals('brian')
      expect(q1.hash()).to.eql q2.hash()

      q1 = query('users').where('votes').lt(20).gt(10).where('followers').gt(100).lt(200)
      q2 = query('users').where('followers').lt(200).gt(100).where('votes').gt(10).lt(20)
      expect(q1.hash()).to.eql q2.hash()

    it 'should create different hashes for different queries', ->
      q1 = query('users').where('name').equals('brian')
      q2 = query('users').where('name').equals('nate')
      expect(q1.hash()).to.not.eql q2.hash()
