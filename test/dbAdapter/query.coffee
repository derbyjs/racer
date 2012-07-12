{expect} = require '../util'
{forEach} = require '../../lib/util/async'
{mockFullSetup} = require '../util/model'
racer = require '../../lib/racer'
shouldFetchDataAsAQuery = require './query.fetch'
shouldBeSubscribable = require './query.subscribe'
shouldSupportPaginatedSubscribe = require './query.paginated'
{augmentStoreOpts} = require '../journalAdapter/util'

module.exports = (storeOpts = {}, plugins = []) ->
  describe 'store mutators', ->
    currCollectionIndex = 0
    nsBase = 'users_'

    beforeEach (done) ->
      @currNs = nsBase + currCollectionIndex++
      for plugin in plugins
        pluginOpts = plugin.testOpts
        racer.use plugin, pluginOpts
      opts = augmentStoreOpts storeOpts, 'lww'
      @racer = racer
      @store = racer.createStore opts
      setTimeout done, 200 # TODO Rm timeout

    afterEach (done) ->
      @store._db.version = 0
      @store.flushMode done

    after (done) ->
      return done() unless store = @store
      store.flush ->
        store.disconnect()
        done()

    shouldFetchDataAsAQuery()

    shouldBeSubscribable plugins

    shouldSupportPaginatedSubscribe plugins

    # These are queries whose parameter values can dynamically change. For
    # example, this could come in handy in the following scenario:
    #
    # model.subscribe 'groups.' + id, (err, group) ->
    #   alias = group.at('todoIds')
    #   model.subscribe model.query('todos').byId(alias), (err, todos) ->
    #     console.log(todos.get()); // => an array of todos
    #
    # In the above example, we want the second subscribe to subscribe to all
    # todos corresponding to ids managed in "group.todoIds". The array of
    # document ids at "group.todoIds" can change, and we want the second
    # subscribe to be able to react to any such change and add/remove Todo
    # documents to the todos results alias `todos`.
    describe 'dependent queries', ->
      it "should send updates when they react to their depedency queries' updates"
      it "should not send updates if its dependency queries emit updates that don't impact the dependent query"


    players = [
      {id: '1', name: {last: 'Nadal',   first: 'Rafael'}, ranking: 2}
      {id: '2', name: {last: 'Federer', first: 'Roger'},  ranking: 3}
      {id: '3', name: {last: 'Djoker',  first: 'Novak'},  ranking: 1}
    ]
    setPlayers = (done) ->
      forEach players, (player, callback) =>
        @store.set "#{@currNs}.#{player.id}", player, null, callback
      , done

    describe 'versioning', ->
      beforeEach setPlayers

      it 'should update the version when the doc is removed from a model because it no longer matches subscriptions', (done) ->
        {store, currNs} = this
        store.query.expose currNs, 'top', (rankingCeiling) ->
          @where('ranking').lte(rankingCeiling)
        mockFullSetup store, done, plugins, (modelA, modelB, done) ->
          oldVer = null
          modelA.on 'rmDoc', ->
            expect(modelA._getVersion()).to.be.greaterThan(oldVer)
            done()
          query = modelA.query(currNs).top(9)
          modelA.subscribe query, ->
            oldVer = modelA._getVersion()
            modelB.set "#{currNs}.1.ranking", 11

      it 'should update the version when the doc is added to a model because it starts to match subscriptions', (done) ->
        {store, currNs} = this
        store.query.expose currNs, 'belowRanking', (ranking) ->
          @where('ranking').gt(ranking)
        mockFullSetup store, done, plugins, (modelA, modelB, done) ->
          oldVer = null
          modelA.on 'addDoc', ->
            expect(modelA._getVersion()).to.be.greaterThan(oldVer)
            done()
          query = modelA.query(currNs).belowRanking(2)
          modelA.subscribe query, ->
            oldVer = modelA._getVersion()
            modelB.set "#{currNs}.1.ranking", 11

    describe 'transaction application', ->
      beforeEach setPlayers

      it 'should apply a txn if a document is still in a query result set after a mutation', (done) ->
        {store, currNs} = this
        store.query.expose currNs, 'numberOne', -> @where('ranking').equals(1)
        mockFullSetup store, done, plugins, (modelA, modelB, done) ->
          modelA.on 'set', "#{currNs}.3.name.last", ->
            expect(modelA.get "#{currNs}.3").to.eql {id: '3', name: {last: 'Djokovic', first: 'Novak'}, ranking: 1}
            done()
          query = modelA.query(currNs).numberOne()
          modelA.subscribe query, ->
            for player in players
              if player.ranking == 1
                expect(modelA.get "#{currNs}.#{player.id}").to.eql player
              else
                expect(modelA.get "#{currNs}.#{player.id}").to.equal undefined
            modelB.set "#{currNs}.3.name.last", 'Djokovic'

      it 'should not apply a txn if a document is being added to a query result set after a mutation', (done) ->
        {store, currNs} = this
        store.query.expose currNs, 'withLastName', (lastName) ->
          @where('name.last').equals(lastName)
        mockFullSetup store, done, plugins, (modelA, modelB, done) ->
          modelA.on 'set', ([path, val]) ->
            return if path.substring(0, 9) == '_$queries' # Ignore setting queries
            if path == "#{currNs}.3"
              expect(modelA.get "#{currNs}.3").to.eql {id: '3', name: {last: 'Djokovic', first: 'Novak'}, ranking: 1}
              done()
            else
              throw new Error "Should not be setting #{path}"
          query = modelA.query(currNs).withLastName('Djokovic')
          modelA.subscribe query, ->
            for player in players
              expect(modelA.get "#{currNs}.#{player.id}").to.equal undefined
            modelB.set "#{currNs}.3.name.last", 'Djokovic'

    describe 'over-subscribing to a doc via 2 queries', ->
      beforeEach setPlayers

      # The following is true because we only pass along transactions
      # whose version is > the socket version. The first time the socket
      # sees the transaction via pubSub, it sends it down to the browser.
      # The second time it sees the now-duplicate transaction, it doesn't
      # send it down because the txn version == socket version.
      it 'should only receive a transaction once if it applies to > 1 query', (done) ->
        {store, currNs} = this
        store.query.expose currNs, 'top', (rankingCeiling) ->
          @where('ranking').lte(rankingCeiling)
        mockFullSetup store, done, plugins, (modelA, modelB, done) ->

          queryZoo = modelA.query(currNs).top(9)
          queryLander = modelA.query(currNs).top(8)
          modelA.subscribe queryZoo, queryLander, ->
            modelA.on 'set', ([path, val], ver) ->
              return if path.substring(0, 9) == '_$queries' # Ignore setting queries
              if path == "#{currNs}.3.name.last"
                expect(modelA.get "#{currNs}.3").to.eql {id: '3', name: {last: 'Djokovic', first: 'Novak'}, ranking: 1}
              else
                throw new Error "Should not be setting #{path}"

            # This will throw an error if called twice
            modelA.socket.on 'txn', (txn, num) -> done()
            modelB.set "#{currNs}.3.name.last", 'Djokovic'
