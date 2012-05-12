{expect} = require './util'
racer = require '../lib/racer'
{mockFullSetup} = require './util/model'

describe 'Offline', ->

  describe '(lww)', ->

    beforeEach ->
      @store = racer.createStore mode: type: 'lww'

    afterEach (done) ->
      @store.flushMode done

    describe 'disconnected for < client throwaway period:', ->

      testBriefOffline = (store, done, {init, mutate, eventual}) ->
        setupOpts = {}
        if init
          setupOpts.preBundle = (model) ->
            for k, v of init
              model.set k, v
            return

        setupOpts.postConnect = (modelA, modelB, done) ->
          modelA.disconnect()
          mutate modelA, modelB
          modelA.connect ->
            process.nextTick -> process.nextTick ->
              expect(modelA.get()).to.specEql modelB.get()
              for path, expectedVal of eventual
                expect(modelA.get path).to.specEql expectedVal
              done()

        mockFullSetup store, done, [], setupOpts

      it 'conflicting txn from server should be applied first, local txn afterwards', (done) ->
        mockFullSetup @store, done, [], (modelA, modelB, done) ->
          modelA.disconnect()

          process.nextTick ->

            modelA.set '_test.name', 'John' # This will be queued in the browser for the server
            modelB.set '_test.name', 'Sue' # This will be queued on server for the browser

            modelA.connect ->
              process.nextTick -> process.nextTick ->
                expect(modelA.get '_test.name').to.specEql 'John'
                done()

      it 'set on same path', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.set '_test.name', 'John'
            connectedModel.set '_test.name', 'Sue'
          eventual:
            '_test.name': 'John'

      it 'set on parent', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.set '_test.user.name', 'John'
            connectedModel.set '_test.user', {}
          eventual:
            '_test.user': {name: 'John'}

      it 'set on child', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.set '_test.user', {}
            connectedModel.set '_test.user.name', 'John'
          eventual:
            '_test.user': {}

      it 'set and del on same path', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.set '_test.user.name', 'John'
            connectedModel.del '_test.user.name'
          eventual:
            '_test.user.name': 'John'

      it 'set and push on same path', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', 'a'
            connectedModel.set '_test.items', []
          eventual:
            '_test.items': ['a']

      it 'pushes on same path', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', 'a', 'b', 'c'
            disconnectedModel.push '_test.items', 'd'
            connectedModel.push '_test.items', 'x', 'y', 'z'
            connectedModel.push '_test.items', 'm', 'n'
          eventual:
            '_test.items': ['x', 'y', 'z', 'm', 'n', 'a', 'b', 'c', 'd']

      it 'unshifts on same path', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.unshift '_test.items', 'a', 'b', 'c'
            disconnectedModel.unshift '_test.items', 'd'
            connectedModel.unshift '_test.items', 'x', 'y', 'z'
            connectedModel.unshift '_test.items', 'm', 'n'
          eventual:
            '_test.items': ['d', 'a', 'b', 'c', 'm', 'n', 'x', 'y', 'z']

      it 'inserts on same path', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.insert '_test.items', 0, 'a', 'b', 'c'
            disconnectedModel.insert '_test.items', 1, 'd'
            connectedModel.insert '_test.items', 0, 'x', 'y', 'z'
            connectedModel.insert '_test.items', 3, 'm', 'n'
          eventual:
            '_test.items': ['a', 'd', 'b', 'c', 'x', 'y', 'z', 'm', 'n']

      it 'push & pop on same path', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', 'a', 'b', 'c'
            disconnectedModel.pop '_test.items'
            connectedModel.push '_test.items', 'x'
            connectedModel.pop '_test.items'
          eventual:
            '_test.items': ['a', 'b']

      it 'moves on same path', (done) ->
        testBriefOffline @store, done,
          init:
            '_test.items': [
              {a: 0}
              {b: 1}
              {c: 2}
              {d: 3}
            ]
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.move '_test.items', 0, 3
            connectedModel.move '_test.items', 3, 0
          eventual:
            '_test.items': [
              {a: 0}
              {b: 1}
              {c: 2}
              {d: 3}
            ]

      it 'moves on same path reverse', (done) ->
        testBriefOffline @store, done,
          init:
            '_test.items': [
              {a: 0}
              {b: 1}
              {c: 2}
              {d: 3}
            ]
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.move '_test.items', 3, 0
            connectedModel.move '_test.items', 0, 3
          eventual:
            '_test.items': [
              {a: 0}
              {b: 1}
              {c: 2}
              {d: 3}
            ]

      it 'push, move, & pop on same path', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', 'a', 'b', 'c'
            disconnectedModel.move '_test.items', 1, 0, 2
            expect(disconnectedModel.get '_test.items').to.specEql ['b', 'c', 'a']
            disconnectedModel.pop '_test.items'
            expect(disconnectedModel.get '_test.items').to.specEql ['b', 'c']

            connectedModel.push '_test.items', 'x', 'y'
            connectedModel.move '_test.items', 0, 1, 1
            expect(connectedModel.get '_test.items').to.specEql ['y', 'x']
            connectedModel.pop '_test.items'
            expect(connectedModel.get '_test.items').to.specEql ['y']

          eventual:
            '_test.items': ['a', 'b', 'y']

      it 'remove both local and remote', (done) ->
        testBriefOffline @store, done,
          init:
            '_test.items': ['x']
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.remove '_test.items', 0
            connectedModel.remove '_test.items', 0
          eventual:
            '_test.items': []

      it 'push & set on array index remote', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', 1
            disconnectedModel.set '_test.items.0', 'x'
            connectedModel.push '_test.items', 2
          eventual:
            '_test.items': ['x', 1]

      it 'push & set on array index local', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', 1
            connectedModel.push '_test.items', 0
            connectedModel.set '_test.items.0', 'x'
          eventual:
            '_test.items': ['x', 1]

      it 'remote set & local push on array child', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.set '_test.items.0.name', 'x'
            connectedModel.push '_test.items', {name: 2}
          eventual:
            '_test.items': [{name: 'x'}]

      it 'remote push & local set on array child', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', {name: 2}
            connectedModel.set '_test.items.0.name', 'x'
          eventual:
            '_test.items': [{name: 'x'}, {name: 2}]

      it 'remote del & local move on array child', (done) ->
        testBriefOffline @store, done,
          init:
            '_test.items': [1, 2, 3]
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.remove '_test.items', 0
            connectedModel.move '_test.items', 0, 2
          eventual:
            '_test.items': [3, 1]

      it 'remote push & set on array child', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', {name: 1}
            disconnectedModel.set '_test.items.0.name', 'x'
            connectedModel.push '_test.items', {name: 2}
          eventual:
            '_test.items': [{name: 'x'}, {name: 1}]

      it 'local push & set on array child', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', {name: 1}
            connectedModel.push '_test.items', {name: 0}
            connectedModel.set '_test.items.0.name', 'x'
          eventual:
            '_test.items': [{name: 'x'}, {name: 1}]

      it 'local push & nested set on array child', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', {name: 1}

            connectedModel.push '_test.items', {name: 0}
            connectedModel.set '_test.items.0.stuff.name', 'x'
          eventual:
            '_test.items': [{name: 0, stuff: name: 'x'}, {name: 1}]

      it 'local push & del on array child', (done) ->
        testBriefOffline @store, done,
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.push '_test.items', {name: 1}
            connectedModel.push '_test.items', {name: 0}
            connectedModel.del '_test.items.0.name'
          eventual:
            '_test.items': [{}, {name: 1}]

      it 'local push & nested del on array child', (done) ->
        testBriefOffline @store, done,
          init:
            '_test.items': [{stuff: {name: 2}}]
          mutate: (disconnectedModel, connectedModel) ->
            disconnectedModel.unshift '_test.items', {name: 1}
            connectedModel.del '_test.items.0.stuff.name'
          eventual:
            '_test.items': [{name: 1}, {stuff: {}}]
