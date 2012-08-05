{expect} = require '../util'
{forEach} = require '../../lib/util/async'

# TODO Test fetch, in addition to subscribe
module.exports = ->
  describe 'fetch', ->
    users = [
      { id: '0', name: 'brian', age: 25, workdays: ['mon', 'tue', 'wed'] }
      { id: '1', name: 'nate' , age: 26, workdays: ['mon', 'wed', 'fri'] }
      { id: '2', name: 'x'    , age: 27, workdays: ['mon', 'thu', 'fri'], height: "7'" }
    ]

    beforeEach (done) ->
      forEach users, (user, callback) =>
        @store.set "#{@currNs}.#{user.id}", user, null, callback
      , done

    describe 'one parameter `exists(true)` queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'withExistingHeight', ->
          @where('height').exists(true)
        @model = @store.createModel()
        @query = @model.query(@currNs).withExistingHeight()

      it 'should load the found docs into the proper namespace', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.2").to.eql users[2]
          done()

      it 'should not load un-found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          for i in [0, 1]
            expect(@model.get "#{@currNs}.#{i}").to.equal undefined
          done()

      it 'should pass back a model alias to a refList of result documents', (done) ->
        @model.subscribe @query, (err, $results) =>
          results = $results.get()
          expect(results).to.have.length 1
          expect(results[0]).to.eql users[2]
          done()

    describe 'one parameter `exists(false)` queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'withNonExistingHeight', ->
          @where('height').exists(false)
        @model = @store.createModel()
        @query = @model.query(@currNs).withNonExistingHeight()

      it 'should load the found docs into the proper namespace', (done) ->
        @model.subscribe @query, =>
          for i in [0, 1]
            expect(@model.get "#{@currNs}.#{i}").to.eql users[i]
          done()

      it 'should not load un-found docs into the proper document namespace', (done) ->
        @model.subscribe @query, =>
          expect(@model.get "#{@currNs}.2").to.equal undefined
          done()

      it 'should pass back a model alias to a refList of result documents', (done) ->
        @model.subscribe @query, (err, $results) =>
          results = $results.get()
          expect(results).to.have.length 2
          for i in [0, 1]
            expect(results[i]).to.eql users[i]
          done()

    describe 'one parameter `equals` queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'withName', (name) ->
          @where('name').equals(name)
        @model = @store.createModel()
        @query = @model.query(@currNs).withName('brian')

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
      beforeEach ->
        @store.query.expose @currNs, 'olderThan', (age) ->
          @where('age').gt(age)
        @model = @store.createModel()
        @query = @model.query(@currNs).olderThan(25)

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
          expect(results).to.eql [users[1], users[2]]
          done()

    describe 'one parameter `gte` queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'xYearsOrOlder', (age) ->
          @where('age').gte(age)
        @model = @store.createModel()
        @query = @model.query(@currNs).xYearsOrOlder(26)

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
          expect(results).to.eql([users[1], users[2]])
          done()

    describe 'one parameter `lt` queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'youngerThan', (age) ->
          @where('age').lt(age)
        @model = @store.createModel()
        @query = @model.query(@currNs).youngerThan(27)

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
          expect(results).to.eql [users[0], users[1]]
          done()

    describe 'one parameter `lte` queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'xYearsOrYounger', (age) ->
          @where('age').lte(age)
        @model = @store.createModel()
        @query = @model.query(@currNs).xYearsOrYounger(26)

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
          expect(results).to.eql [users[0], users[1]]
          done()

    describe 'one parameter `within` queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'withinNames', (names) ->
          @where('name').within(names)
        @model = @store.createModel()
        @query = @model.query(@currNs).withinNames(['brian', 'x'])

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
          expect(results).to.eql [users[0], users[2]]
          done()

    describe 'one parameter `contains` scalar queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'workingAny', (workdays) ->
          @where('workdays').contains(workdays)
        @model = @store.createModel()
        @query = @model.query(@currNs).workingAny(['mon', 'wed'])

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
          expect(results).to.eql [users[0], users[1]]
          done()

    describe 'composable queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'workingAll', (workdays) ->
          @where('workdays').contains(workdays)
        @store.query.expose @currNs, 'olderThan', (age) ->
          @where('age').gt(age)
        @model = @store.createModel()
        @query = @model.query(@currNs).workingAll(['wed']).olderThan(25)

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

      it 'should be able to specify `one` to force a find-one', (done) ->
        @model.subscribe @query.one(), (err, $result) ->
          result = $result.get()
          expect(result).to.eql users[1]
          done()

      it 'should be able to specify `count` to force an aggregate query', (done) ->
        @model.subscribe @query.count(), (err, $result) ->
          result = $result.get()
          expect(result).to.equal 1
          done()

    describe '`only` queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'olderThanWithNameAndAge', (age) ->
          @where('age').gt(age).only('name', 'age')
        @model = @store.createModel()
        @query = @model.query(@currNs).olderThanWithNameAndAge(20)

      it 'should only retrieve the paths specified in `only`', (done) ->
        @model.subscribe @query, =>
          for i in [0..2]
            expect(@model.get @currNs + '.' + i + '.id').to.equal users[i].id
            expect(@model.get @currNs + '.' + i + '.name').to.equal users[i].name
            expect(@model.get @currNs + '.' + i + '.age').to.equal users[i].age
            expect(@model.get @currNs + '.' + i + '.workdays').to.equal undefined
          done()

    describe '`except` queries', ->
      beforeEach ->
        @store.query.expose @currNs, 'olderThanExceptNameAndWorkdays', (age) ->
          @where('age').gt(age).except('name', 'workdays')
        @model = @store.createModel()
        @query = @model.query(@currNs).olderThanExceptNameAndWorkdays(20)

      it 'should exclude paths specified in `except`', (done) ->
        @model.subscribe @query, =>
          for i in [0..2]
            expect(@model.get @currNs + '.' + i + '.id').to.equal users[i].id
            expect(@model.get @currNs + '.' + i + '.age').to.equal users[i].age
            expect(@model.get @currNs + '.' + i + '.name').to.equal undefined
            expect(@model.get @currNs + '.' + i + '.workdays').to.equal undefined
          done()
