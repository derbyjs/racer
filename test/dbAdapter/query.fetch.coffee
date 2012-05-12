{expect} = require '../util'
{forEach} = require '../../lib/util/async'

module.exports = ->
  describe 'fetch', ->
    users = [
      { id: '0', name: 'brian', age: 25, workdays: ['mon', 'tue', 'wed'] }
      { id: '1', name: 'nate' , age: 26, workdays: ['mon', 'wed', 'fri'] }
      { id: '2', name: 'x'    , age: 27, workdays: ['mon', 'thu', 'fri'] }
    ]

    beforeEach (done) ->
      forEach users, (user, callback) =>
        @store.set "#{@currNs}.#{user.id}", user, null, callback
      , done

    it 'should work for one parameter `equals` queries', (done) ->
      {store, currNs} = this
      model = store.createModel()
      query = model.query(currNs).where('name').equals('brian')
      model.subscribe query, ->
        expect(model.get "#{currNs}.0").to.eql users[0]
        expect(model.get "#{currNs}.1").to.equal undefined
        expect(model.get "#{currNs}.2").to.equal undefined
        done()

    it 'should work for one parameter `gt` queries', (done) ->
      {store, currNs} = this
      model = store.createModel()
      query = model.query(currNs).where('age').gt(25)
      model.subscribe query, ->
        expect(model.get "#{currNs}.0").to.equal undefined
        for i in [1, 2]
          expect(model.get currNs + '.' + i).to.eql users[i]
        done()

    it 'should work for one parameter `gte` queries', (done) ->
      {store, currNs} = this
      model = store.createModel()
      query = model.query(currNs).where('age').gte(26)
      model.subscribe query, ->
        expect(model.get "#{currNs}.0").to.equal undefined
        for i in [1, 2]
          expect(model.get currNs + '.' + i).to.eql users[i]
        done()

    it 'should work for one parameter `lt` queries', (done) ->
      {store, currNs} = this
      model = store.createModel()
      query = model.query(currNs).where('age').lt(27)
      model.subscribe query, ->
        for i in [0, 1]
          expect(model.get currNs + '.' + i).to.eql users[i]
        expect(model.get "#{currNs}.2").to.equal undefined
        done()

    it 'should work for one parameter `lte` queries', (done) ->
      {store, currNs} = this
      model = store.createModel()
      query = model.query(currNs).where('age').lte(26)
      model.subscribe query, ->
        for i in [0, 1]
          expect(model.get currNs + '.' + i).to.eql users[i]
        expect(model.get "#{currNs}.2").to.equal undefined
        done()

    it 'should work for one parameter `within` queries', (done) ->
      {store, currNs} = this
      model = store.createModel()
      query = model.query(currNs).where('name').within(['brian', 'x'])
      model.subscribe query, ->
        for i in [0, 2]
          expect(model.get currNs + '.' + i).to.eql users[i]
        expect(model.get "#{currNs}.1").to.equal undefined
        done()

    it 'should work for one parameter `contains` scalar queries', (done) ->
      {store, currNs} = this
      model = store.createModel()
      query = model.query(currNs).where('workdays').contains(['mon', 'wed'])
      model.subscribe query, ->
        for i in [0, 1]
          expect(model.get currNs + '.' + i).to.eql users[i]
        expect(model.get "#{currNs}.2").to.equal undefined
        done()

    it 'should work for compound queries', (done) ->
      {store, currNs} = this
      model = store.createModel()
      query = model.query(currNs).where('workdays').contains(['wed']).where('age').gt(25)
      model.subscribe query, ->
        for i in [0, 2]
          expect(model.get currNs + '.' + i).to.equal undefined
        expect(model.get "#{currNs}.1").to.eql users[1]
        done()

    it 'should only retrieve paths specified in `only`', (done) ->
      {store, currNs} = this
      model = store.createModel()
      query = model.query(currNs).where('age').gt(20).only('name', 'age')
      model.subscribe query, ->
        for i in [0..2]
          expect(model.get currNs + '.' + i + '.id').to.equal users[i].id
          expect(model.get currNs + '.' + i + '.name').to.equal users[i].name
          expect(model.get currNs + '.' + i + '.age').to.equal users[i].age
          expect(model.get currNs + '.' + i + '.workdays').to.equal undefined
        done()

    it 'should exclude paths specified in `except`', (done) ->
      {store, currNs} = this
      model = store.createModel()
      query = model.query(currNs).where('age').gt(20).except('name', 'workdays')
      model.subscribe query, ->
        for i in [0..2]
          expect(model.get currNs + '.' + i + '.id').to.equal users[i].id
          expect(model.get currNs + '.' + i + '.age').to.equal users[i].age
          expect(model.get currNs + '.' + i + '.name').to.equal undefined
          expect(model.get currNs + '.' + i + '.workdays').to.equal undefined
        done()
