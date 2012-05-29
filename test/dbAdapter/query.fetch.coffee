{expect} = require '../util'
{forEach} = require '../../lib/util/async'

# TODO Test fetch, in addition to subscribe
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
      , =>
        @model = @store.createModel()
        done()

    describe 'one parameter `equals` queries', ->
      beforeEach -> @query = @racer.query(@currNs).where('name').equals('brian')

      it 'should load the found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.0").to.eql users[0]
          done()

      it 'should not load un-found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.1").to.equal undefined
          expect(@model.get "#{@currNs}.2").to.equal undefined
          done()

      it 'should pass back a model alias to a refList of result documents', (done) ->
        @model.subscribe @query, (err, resultsAlias) =>
          results = resultsAlias.get()
          expect(results).to.have.length(1)
          expect(results[0]).to.eql users[0]
          done()

    describe 'one parameter `gt` queries', ->
      beforeEach -> @query = @racer.query(@currNs).where('age').gt(25)

      it 'should load the found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          for i in [1, 2]
            expect(@model.get @currNs + '.' + i).to.eql users[i]
          done()

      it 'should not load un-found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.0").to.equal undefined
          done()

      it 'should pass back a model alias to a refList of result documents', (done) ->
        @model.subscribe @query, (err, resultsAlias) ->
          results = resultsAlias.get()
          expect(results).to.have.length(2)
          expect(results).to.eql [users[2], users[1]]
          done()

    describe 'one parameter `gte` queries', ->
      beforeEach -> @query = @racer.query(@currNs).where('age').gte(26)

      it 'should load the found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          for i in [1, 2]
            expect(@model.get @currNs + '.' + i).to.eql users[i]
          done()

      it 'should not load the un-found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.0").to.equal undefined
          done()

      it 'should pass back a model alias to a refList of result documents', (done) ->
        @model.subscribe @query, (err, resultsAlias) ->
          results = resultsAlias.get()
          expect(results).to.have.length(2)
          expect(results).to.eql([users[2], users[1]])
          done()

    describe 'one parameter `lt` queries', ->
      beforeEach -> @query = @racer.query(@currNs).where('age').lt(27)

      it 'should load the found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          for i in [0, 1]
            expect(@model.get @currNs + '.' + i).to.eql users[i]
          done()

      it 'should not load the un-found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.2").to.equal undefined
          done()

      it 'should pass back a model alias to a refList of result documents', (done) ->
        @model.subscribe @query, (err, resultsAlias) ->
          results = resultsAlias.get()
          expect(results).to.have.length(2)
          expect(results).to.eql [users[1], users[0]]
          done()

    describe 'one parameter `lte` queries', ->
      beforeEach -> @query = @racer.query(@currNs).where('age').lte(26)

      it 'should load the found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          for i in [0, 1]
            expect(@model.get @currNs + '.' + i).to.eql users[i]
          done()

      it 'should not load the un-found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.2").to.equal undefined
          done()

      it 'should pass back a model alias to a refList of result documents', (done) ->
        @model.subscribe @query, (err, resultsAlias) ->
          results = resultsAlias.get()
          expect(results).to.have.length(2)
          expect(results).to.eql [users[1], users[0]]
          done()

    describe 'one parameter `within` queries', ->
      beforeEach -> @query = @racer.query(@currNs).where('name').within(['brian', 'x'])

      it 'should load the found docs into the proper document namespaces', (done) ->
        @model.subscribe @query, =>
          for i in [0, 2]
            expect(@model.get @currNs + '.' + i).to.eql users[i]
          done()

      it 'should not load the un-found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.1").to.equal undefined
          done()

      it 'should pass back a model alias to a refList of result documents', (done) ->
        @model.subscribe @query, (err, resultsAlias) ->
          results = resultsAlias.get()
          expect(results).to.have.length(2)
          expect(results).to.eql [users[2], users[0]]
          done()

    describe 'one parameter `contains` scalar queries', ->
      beforeEach -> @query = @racer.query(@currNs).where('workdays').contains(['mon', 'wed'])

      it 'should load the found docs into the proper document namespaces', (done) ->
        @model.subscribe @query, =>
          for i in [0, 1]
            expect(@model.get @currNs + '.' + i).to.eql users[i]
          done()

      it 'should not load the un-found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.2").to.equal undefined
          done()

      it 'should pass back a model alias to a refList of result documents', (done) ->
        @model.subscribe @query, (err, resultsAlias) ->
          results = resultsAlias.get()
          expect(results).to.have.length(2)
          expect(results).to.eql [users[1], users[0]]
          done()

    describe 'compound queries', ->
      beforeEach -> @query = @racer.query(@currNs).where('workdays').contains(['wed']).where('age').gt(25)

      it 'should load the found docs into the proper document namespaces', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.1").to.eql users[1]
          done()

      it 'should not load the un-found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          for i in [0, 2]
            expect(@model.get @currNs + '.' + i).to.equal undefined
          done()

      it 'should pass back a model alias to a refList of result documents', (done) ->
        @model.subscribe @query, (err, resultsAlias) =>
          results = resultsAlias.get()
          expect(results).to.have.length(1)
          expect(results).to.eql [users[1]]
          done()

    describe '`only` queries', ->
      beforeEach -> @query = @racer.query(@currNs).where('age').gt(20).only('name', 'age')

      it 'should only retrieve the paths specified in `only`', (done) ->
        @model.subscribe @query, =>
        for i in [0..2]
          expect(@model.get @currNs + '.' + i + '.id').to.equal users[i].id
          expect(@model.get @currNs + '.' + i + '.name').to.equal users[i].name
          expect(@model.get @currNs + '.' + i + '.age').to.equal users[i].age
          expect(@model.get @currNs + '.' + i + '.workdays').to.equal undefined
        done()

    describe '`except` queries', ->
      beforeEach -> @query = @racer.query(@currNs).where('age').gt(20).except('name', 'workdays')

      it 'should exclude paths specified in `except`', (done) ->
        @model.subscribe @query, =>
          for i in [0..2]
            expect(@model.get @currNs + '.' + i + '.id').to.equal users[i].id
            expect(@model.get @currNs + '.' + i + '.age').to.equal users[i].age
            expect(@model.get @currNs + '.' + i + '.name').to.equal undefined
            expect(@model.get @currNs + '.' + i + '.workdays').to.equal undefined
          done()
