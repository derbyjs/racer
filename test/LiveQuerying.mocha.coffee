should = require 'should'
Store = require '../src/Store'
redis = require 'redis'
async = require 'async'

describe 'Live Querying', ->

  store = null

  describe 'with Mongo', ->

    beforeEach ->
      MongoAdapter = require '../src/adapters/Mongo'
      mongo = new MongoAdapter 'mongodb://localhost/database'
      mongo.connect()
      # Can't make this a `before` callback because redis pub/sub
      # may bleed from one test into the next
      store = new Store
        adapter: mongo
        stm: false

    afterEach (done) ->
      store.flush ->
        # TODO Hide these end() calls behind a better
        #      method abstraction
        store._redisClient.end()
        store._subClient.end()
        store._txnSubClient.end()
        done()

    describe 'subscribe fetches', ->
      users = [
        { id: '0', name: 'brian', age: 25, workdays: ['mon', 'tue', 'wed'] }
        { id: '1', name: 'nate' , age: 26, workdays: ['mon', 'wed', 'fri'] }
        { id: '2', name: 'x'    , age: 27, workdays: ['mon', 'thu', 'fri'] }
      ]

      beforeEach (done) ->
        ver = 0
        async.forEach users
        , (user, callback) ->
          store.set "users.#{user.id}", user, ++ver, callback
        , done

      it 'should work for one parameter `equals` queries', (done) ->
        model = store.createModel()
        query = model.query('users').where('name').equals('brian')
        model.subscribe query, ->
          model.get('users.0').should.eql users[0]
          should.equal undefined, model.get('users.1')
          should.equal undefined, model.get('users.2')
          done()

      it 'should work for one parameter `gt` queries', (done) ->
        model = store.createModel()
        query = model.query('users').where('age').gt(25)
        model.subscribe query, ->
          should.equal undefined, model.get('users.0')
          for i in [1, 2]
            model.get('users.' + i).should.eql users[i]
          done()

      it 'should work for one parameter `gte` queries', (done) ->
        model = store.createModel()
        query = model.query('users').where('age').gte(26)
        model.subscribe query, ->
          should.equal undefined, model.get('users.0')
          for i in [1, 2]
            model.get('users.' + i).should.eql users[i]
          done()

      it 'should work for one parameter `lt` queries', (done) ->
        model = store.createModel()
        query = model.query('users').where('age').lt(27)
        model.subscribe query, ->
          for i in [0, 1]
            model.get('users.' + i).should.eql users[i]
          should.equal undefined, model.get('users.2')
          done()

      it 'should work for one parameter `lte` queries', (done) ->
        model = store.createModel()
        query = model.query('users').where('age').lte(26)
        model.subscribe query, ->
          for i in [0, 1]
            model.get('users.' + i).should.eql users[i]
          should.equal undefined, model.get('users.2')
          done()

      it 'should work for one parameter `within` queries', (done) ->
        model = store.createModel()
        query = model.query('users').where('name').within(['brian', 'x'])
        model.subscribe query, ->
          for i in [0, 2]
            model.get('users.' + i).should.eql users[i]
          should.equal undefined, model.get('users.1')
          done()

      it 'should work for one parameter `contains` scalar queries', (done) ->
        model = store.createModel()
        query = model.query('users').where('workdays').contains(['mon', 'wed'])
        model.subscribe query, ->
          for i in [0, 1]
            model.get('users.' + i).should.eql users[i]
          should.equal undefined, model.get('users.2')
          done()

      it 'should work for compound queries', (done) ->
        model = store.createModel()
        query = model.query('users').where('workdays').contains(['wed']).where('age').gt(25)
        model.subscribe query, ->
          for i in [0, 2]
            should.equal undefined, model.get('users.' + i)
          model.get('users.1').should.eql users[1]
          done()

    describe 'setting <namespace>.<id>', ->

  describe 'with Memory', ->
