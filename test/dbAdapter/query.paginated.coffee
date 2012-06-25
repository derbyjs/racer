{expect} = require '../util'
{forEach} = require '../../lib/util/async'
{mockFullSetup} = require '../util/model'

module.exports = (plugins) ->
  describe 'paginated', ->
    players = [
      {id: '1', name: {last: 'Nadal',   first: 'Rafael'}, ranking: 2}
      {id: '2', name: {last: 'Federer', first: 'Roger'},  ranking: 3}
      {id: '3', name: {last: 'Djoker',  first: 'Novak'},  ranking: 1}
    ]

    beforeEach (done) ->
      {store, currNs} = this
      forEach players, (player, callback) ->
        store.set "#{currNs}.#{player.id}", player, null, callback
      , done

    checkItems = (currNs, modelA, defined) ->
      for i in [1..3]
        prop = if ~defined.indexOf(i) then 'not' else 'to'
        expect(modelA.get "#{currNs}.#{i}")[prop].equal undefined
      return

    test = ({withStore, events, definedBefore, definedAfter, onSubscribe}) ->
      return (done) ->
        {store, currNs} = testContext = this
        withStore.call testContext, store
        mockFullSetup store, done, plugins, (modelA, modelB, done) ->
          forEach events, (event, callback) ->
            modelA.on event, ->
              callback()
          , ->
            checkItems currNs, modelA, definedAfter
            done()
          target = modelA.query(currNs).special()
          modelA.subscribe target, ->
            checkItems currNs, modelA, definedBefore
            onSubscribe.call testContext, modelB, currNs

    describe 'for non-saturated result sets (e.g., limit=10, sizeof(resultSet) < 10)', ->
      # TODO Uncomment the test body below when we support pagination
      it 'should add a document that satisfies the query'#, test
#        query: (ranking) -> ranking.gte(3).limit(2)
#        onSubscribe: (modelB) -> modelB.set "#{@currNs}.1.ranking", 4
#        events: ['addDoc']
#        definedBefore: [2]
#        definedAfter:  [1, 2]

      it 'should remove a document that no longer satisfies the query', test
        withStore: (store) ->
          store.query.expose @currNs, 'special', ->
            @where('ranking').lt(2).sort('ranking', 'asc').limit(2)
        onSubscribe: (modelB) -> modelB.set "#{@currNs}.3.ranking", 2
        events: ['rmDoc']
        definedBefore: [3]
        definedAfter:  []

    # TODO Test multi-param sorts
    describe 'for saturated result sets (i.e., limit == sizeof(resultSet))', ->

      it 'should replace a document (whose recent mutation makes it in-compatible with the query) if another doc in the db is compatible', test
      #   <page prev> <page curr> <page next>
      #                   -                     push to curr from next
        withStore: (store) ->
          store.query.expose @currNs, 'special', ->
            @where('ranking').lt(5).sort('ranking', 'asc').limit(2)
        onSubscribe: (modelB) -> modelB.set "#{@currNs}.3.ranking", 6
        events: ['rmDoc', 'addDoc']
        definedBefore: [1, 3]
        definedAfter:  [1, 2]

      it 'should replace a document if another doc was just mutated so it supercedes the doc according to the query', test
        #   <page prev> <page curr> <page next>
        #                   +                     pop from curr to next
        withStore: (store) ->
          store.query.expose @currNs, 'special', ->
            @where('ranking').lt(3).sort('name.first', 'desc').limit(2)
        onSubscribe: (modelB) -> modelB.set "#{@currNs}.2.ranking", 2
        events: ['rmDoc', 'addDoc']
        definedBefore: [1, 3]
        definedAfter:  [1, 2]

      # TODO Uncomment the test body below when we support pagination
      it 'should keep a document that just re-orders the query result set'#, test
#      #   <page prev> <page curr> <page next>
#      #                   -><-                  re-arrange curr members
#        query: (ranking) -> ranking.lt(10).sort('ranking', 'asc').limit(2)
#        onSubscribe: (modelB) -> modelB.set "#{@currNs}.1.ranking", 0
#        events: ['set']
#        definedBefore: [1, 3]
#        definedAfter:  [1, 3]


      testSetup = (store, currNs, done, callback) ->
        mockFullSetup store, done, plugins, (modelA, modelB, done) ->
          newPlayers = [
            {id: '4', name: {first: 'David', last: 'Ferrer'}, ranking: 5}
            {id: '5', name: {first: 'Andy',  last: 'Murray'}, ranking: 4}
          ]
          allPlayers = players.concat newPlayers
          forEach newPlayers, (player, finish) ->
            store.set "#{currNs}.#{player.id}", player, null, finish
          , -> callback allPlayers, modelA, modelB, done

      test = ({withStore, expectedRange, onSubscribe}) ->
        return (done) ->
          {store, currNs} = testContext = this
          withStore.call testContext, store
          testSetup store, currNs, done, (allPlayers, modelA, modelB, done) ->
            forEach ['rmDoc', 'addDoc'], (method, finish) ->
              modelA.on method, ->
                finish()
            , ->
              modelPlayers = modelA.get currNs
              for id, player of modelPlayers
                expect(player.ranking).to.be.within expectedRange...
              done()
            target = modelA.query(currNs).special()
            modelA.subscribe target, ->
              for player in allPlayers
                if player.ranking not in [3, 4]
                  expect(modelA.get "#{currNs}.#{player.id}").to.equal undefined
                else
                  expect(modelA.get "#{currNs}.#{player.id}").to.eql player
              onSubscribe.call testContext, modelB

      it 'should shift a member out and push a member in when a prev page document fails to satisfy the query', test
      #   <page prev> <page curr> <page next>
      #       -                                 shift from curr to prev
      #                                         push to curr from right
        withStore: (store) ->
          store.query.expose @currNs, 'special', ->
            @where('ranking').lte(5).sort('ranking', 'asc').limit(2).skip(2)
        expectedRange: [4, 5]
        onSubscribe: (modelB) -> modelB.set "#{@currNs}.1.ranking", 6

      it 'should shift a member out and push a member in when a prev page document mutates in a way forcing it to move to the current page to maintain order', test
      #   <page prev> <page curr> <page next>
      #       -   >>>>>   +                     shift from curr to prev
      #                                         insert + in curr
        withStore: (store) ->
          store.query.expose @currNs, 'special', ->
            @where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
        expectedRange: [4, 5]
        onSubscribe: (modelB) -> modelB.set "#{@currNs}.1.ranking", 5

      it 'should shift a member out and push a member in when a prev page document mutates in a way forcing it to move to a subsequent page to maintain order', test
      #   <page prev> <page curr> <page next>
      #       -   >>>>>>>>>>>>>>>>>   +         shift from curr to prev
      #                                         push from next to curr
        withStore: (store) ->
          store.query.expose @currNs, 'special', ->
            @where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
        expectedRange: [4, 5]
        onSubscribe: (modelB) -> modelB.set "#{@currNs}.1.ranking", 6

      it 'should move an existing result from a prev page if a mutation causes a new member to be added to the prev page', test
      #   <page prev> <page curr> <page next>
      #       +                                 unshift to curr from prev
      #                                         pop from curr to next
        withStore: (store) ->
          store.query.expose @currNs, 'special', ->
            @where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
        expectedRange: [2, 3]
        onSubscribe: (modelB) -> modelB.set "#{@currNs}.6",
          {id: '6', name: {first: 'Pete', last: 'Sampras'}, ranking: 0}

      it 'should move the last member of the prev page to the curr page, if a curr page member mutates in a way that moves it to a prev page', test
      #   <page prev> <page curr> <page next>
      #       +   <<<<<   -                     unshift to curr from prev
        withStore: (store) ->
          store.query.expose @currNs, 'special', ->
            @where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
        expectedRange: [2, 3]
        onSubscribe: (modelB) -> modelB.set "#{@currNs}.5.ranking", 0


      test = ({withStore, expectedRange, onSubscribe}) ->
        return (done) ->
          {store, currNs} = testContext = this
          withStore.call testContext, store
          testSetup store, currNs, done, (allPlayers, modelA, modelB, done) ->
            modelA.on 'addDoc', -> done() # Should never be called
            modelA.on 'rmDoc', -> done() # Should never be called
            setTimeout ->
              modelPlayers = modelA.get currNs
              for id, player of modelPlayers
                expect(player.ranking).to.be.within expectedRange...
              done()
            , 50
            target = modelA.query(currNs).special()
            modelA.subscribe target, ->
              for player in allPlayers
                if player.ranking not in [3, 4]
                  expect(modelA.get "#{currNs}.#{player.id}").to.equal undefined
                else
                  expect(modelA.get "#{currNs}.#{player.id}").to.eql player
              onSubscribe modelB

      it 'should do nothing to the curr page if mutations only add docs to subsequent pages', test
      #   <page prev> <page curr> <page next>
      #                               +         do nothing to curr
        withStore: (store) ->
          store.query.expose @currNs, 'special', ->
            @where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
        expectedRange: [3, 4]
        onSubscribe: (modelB) -> modelB.set "#{@currNs}.4.ranking", 5

      it 'should do nothing to the curr page if mutations only remove docs from subsequent pages', test
      #   <page prev> <page curr> <page next>
      #                               -         do nothing to curr
        withStore: (store) ->
          store.query.expose @currNs, 'special', ->
            @where('ranking').lte(6).sort('ranking', 'asc').limit(2).skip(2)
        expectedRange: [3, 4]
        onSubscribe: (modelB) -> modelB.set "#{@currNs}.4.ranking", 10
