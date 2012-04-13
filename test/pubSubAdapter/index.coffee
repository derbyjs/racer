{expect} = require '../util'
racer = require '../../lib/racer'
transaction = require '../../lib/transaction'
shouldPassStoreIntegrationTests = require '../Store/integration'
{deepEqual} = require '../../lib/util'
{augmentStoreOpts} = require '../journalAdapter/util'

shouldBehaveLikePubSubAdapter = module.exports = (storeOpts = {}, plugins = []) ->

  shouldPassStoreIntegrationTests storeOpts, plugins

  describe 'subscribe/publish', ->

    beforeEach (done) ->
      for plugin in plugins
        racer.use plugin, plugin.testOpts if plugin.useWith.server
      opts = augmentStoreOpts storeOpts, 'lww'
      @store = racer.createStore opts
      @store.flush done

    afterEach (done) ->
      @store.flushMode =>
        @store.disconnect()
        done()

    path = 'ns.1.key'
    txn = transaction.create ver: 0, id: '1.1', method: 'set', args: [path, 'val']

    it 'a published transaction to the same path should be received if subscribed to', (done) ->
      pubSub = @store._pubSub
      pubSub.on 'txn', (subscriberId, data) ->
        expect(subscriberId).to.equal '1'
        expect(data).to.eql txn
        done()

      pubSub.subscribe '1', [path], ->
        pubSub.publish
          type: 'txn'
          params:
            channel: path
            data: txn

    it 'a published transaction to a subpath should be received if subscribed to', (done) ->
      pubSub = @store._pubSub
      pubSub.on 'txn', (subscriberId, data) ->
        expect(subscriberId).to.equal '1'
        expect(data).to.eql txn
        done()

      pubSub.subscribe '1', ['ns.1'], ->
        # Should match
        pubSub.publish
          type: 'txn'
          params:
            channel: path
            data: txn
        # Should not match
        pubSub.publish
          type: 'txn'
          params:
            channel: 'ns.2'
            data: txn

    it 'a published transaction to a patterned `prefix.*.suffix` path should only be received if subscribed to', (done) ->

      pathOne = 'docs.1.suffix'
      txnOne = transaction.create ver: 0, id: '1.1', method: 'set', args: [pathOne, 'valueOne']

      pathTwo = 'docs.1.nomatch'
      txnTwo = transaction.create ver: 0, id: '1.2', method: 'set', args: [pathTwo, 'valueTwo']

      pathThree = pathOne
      txnThree = transaction.create ver: 0, id: '1.3', method: 'set', args: [pathThree, 'valueThree']

      counter = 0
      expected = [txnOne, txnThree]
      pubSub = @store._pubSub
      pubSub.on 'txn', (subscriberId, data) ->
        expect(subscriberId).to.equal '1'
        expect(data).to.eql expected[counter++]
        done() if counter == 2

      pubSub.subscribe '1', ['docs.*.suffix'], ->
        pubSub.publish
          type: 'txn'
          params:
            channel: pathOne
            data: txnOne
        pubSub.publish
          type: 'txn'
          params:
            channel: pathTwo
            data: txnTwo
        pubSub.publish
          type: 'txn'
          params:
            channel: pathThree
            data: txnThree

    it 'unsubscribing from a path that is not subscribed to should be harmless', (done) ->
      pubSub = @store._pubSub
      pubSub.unsubscribe 'subcriber', ['not-subscribed-to-this-channel'], done

    it 'unsubscribing from a path means the subscriber should no longer receive the path messages', (done) ->
      pathOne = 'docs.1.a'
      pathTwo = 'docs.1.b'

      txnOne = transaction.create ver: 0, id: '1.1', method: 'set', args: [pathOne, 'first']
      txnTwo = transaction.create ver: 0, id: '1.2', method: 'set', args: [pathTwo, 'second']
      txnIgnored = transaction.create ver: 0, id: '1.3', method: 'set', args: [pathOne, 'ignored']
      txnLast = transaction.create ver: 0, id: '1.4', method: 'set', args: [pathTwo, 'last']

      counter = 0
      pubSub = @store._pubSub
      pubSub.on 'txn', (subscriberId, data) ->
        counter++
        if deepEqual data, txnLast
          expect(counter).to.equal 3
          done()

      pubSub.subscribe '1', [pathOne, pathTwo], ->
        pubSub.publish
          type: 'txn'
          params:
            channel: pathOne
            data: txnOne
        pubSub.publish
          type: 'txn'
          params:
            channel: pathTwo
            data: txnTwo
        setTimeout ->
          pubSub.unsubscribe '1', [pathOne], ->
            pubSub.publish
              type: 'txn'
              params:
                channel: pathOne
                data: txnIgnored
            pubSub.publish
              type: 'txn'
              params:
                channel: pathTwo
                data: txnLast
          , true
        , 50
      , true

    it 'unsubscribing from a pattern means the subscriber should no longer receive the pattern messages', (done) ->
      pathOne = 'a.1.1'
      txnOne = transaction.create ver: 0, id: '1.1.', method: 'set', args: [pathOne, 'val']

      pathTwo = 'b.2.1'
      txnTwo = transaction.create ver: 0, id: '1.2', method: 'set', args: [pathTwo, 'val']

      pathIgnored = 'a.1.2'
      txnIgnored = transaction.create ver: 0, id: '1.3', method: 'set', args: [pathIgnored, 'val']

      pathLast = 'b.2.2'
      txnLast = transaction.create ver: 0, id: '1.4', method: 'set', args: [pathLast, 'val']

      counter = 0
      pubSub = @store._pubSub
      pubSub.on 'txn', (subscriberId, data) ->
        counter++
        if deepEqual data, txnLast
          expect(counter).to.equal 3
          done()

      pubSub.subscribe '1', ['a.1.*', 'b.2.*'], ->
        pubSub.publish
          type: 'txn'
          params:
            channel: pathOne
            data: txnOne
        pubSub.publish
          type: 'txn'
          params:
            channel: pathTwo
            data: txnTwo
        setTimeout ->
          pubSub.unsubscribe '1', ['a.1.*'], ->
            pubSub.publish
              type: 'txn'
              params:
                channel: pathIgnored
                data: txnIgnored
            pubSub.publish
              type: 'txn'
              params:
                channel: pathLast
                data: txnLast
        , 50

    it 'subscribing > 1 time to the same path should still only result in the subscriber receiving the message once', (done) ->
      pathOne = 'docs.1'
      txnOne = transaction.create ver: 0, id: '1.1', method: 'set', args: [pathOne, id: '100']
      txnLast = transaction.create ver: 0, id: '1.2', method: 'set', args: [pathOne, id: '101']

      counter = 0
      pubSub = @store._pubSub
      pubSub.on 'txn', (subscriberId, data) ->
        counter++
        if deepEqual data, txnLast
          expect(counter).to.equal 2
          done()

      pubSub.subscribe '1', [pathOne], ->
        pubSub.subscribe '1', [pathOne], ->
          pubSub.publish
            type: 'txn'
            params:
              channel: pathOne
              data: txnOne
          pubSub.publish
            type: 'txn'
            params:
              channel: pathOne
              data: txnLast

    it 'subscribing > 1 time to the same pattern should still only result in the subscriber receiving the message once', (done) ->
      pathFirst = 'docs.1.name'
      txnFirst = transaction.create ver: 0, id: '1.1', method: 'set', args: [pathFirst, 'brian']
      pathLast= 'docs.2.name'
      txnLast = transaction.create ver: 0, id: '1.1', method: 'set', args: [pathLast, 'nate']
      counter = 0

      pubSub = @store._pubSub
      pubSub.on 'txn', (subscriberId, data) ->
        counter++
        if deepEqual data, txnLast
          expect(counter).to.equal 2
          done()

      pubSub.subscribe '1', ['docs.*.name'], ->
        pubSub.subscribe '1', ['docs.*.name'], ->
          pubSub.publish
            type: 'txn'
            params:
              channel: pathFirst
              data: txnFirst

          pubSub.publish
            type: 'txn'
            params:
              channel: pathLast
              data: txnLast

    it 'overlapping patterns are expected to duplicate callbacks', (done) ->
      pathOne = 'docs.1.name.first'
      txnOne = transaction.create ver: 0, id: '1.1', method: 'set', args: [pathOne, 'brian']

      pathTwo = 'docs.1.city'
      txnTwo = transaction.create ver: 0, id: '1.2', method: 'set', args: [pathTwo, 'san francisco']


      counter = 0
      pubSub = @store._pubSub

      pubSub.on 'txn', (subscriberId, data) ->
        counter++
        if deepEqual data, txnTwo
          expect(counter).to.equal 3
          done()

      pubSub.subscribe '1', ['docs.1.*'], ->
        pubSub.subscribe '1', ['docs.1.name.*'], ->
          [[pathOne, txnOne], [pathTwo, txnTwo]].forEach ([path, txn]) ->
            pubSub.publish
              type: 'txn'
              params:
                channel: path
                data: txn

    it '2 subscribers to the same path should both receive messages', (done) ->
      counter = 2
      subscribersWithReceipt = {}
      pubSub = @store._pubSub
      pubSub.on 'txn', (subscriberId, data) ->
        subscribersWithReceipt[subscriberId] = true
        return if --counter
        expect(subscribersWithReceipt).to.eql '1': true, '2': true
        done()

      pubSub.subscribe '1', ['docs.1.name'], ->
        pubSub.subscribe '2', ['docs.1.name'], ->
          pubSub.publish
            type: 'txn'
            params:
              channel: 'docs.1.name'
              data: transaction.create(ver: 0, id: '1.1', method: 'set', args: ['docs.1.name', 'cyclops'])

    it '2 subscribers to the same pattern should both receive messages', (done) ->
      counter = 2
      subscribersWithReceipt = {}
      pubSub = @store._pubSub
      pubSub.on 'txn', (subscriberId, message) ->
        subscribersWithReceipt[subscriberId] = true
        return if --counter
        expect(subscribersWithReceipt).to.eql '1': true, '2': true
        done()

      pubSub.subscribe '1', ['docs.*.city'], ->
        pubSub.subscribe '2', ['docs.*.city'], ->
          pubSub.publish
            type: 'txn'
            params:
              channel: 'docs.1.city'
              data: transaction.create(ver: 0, id: '1.1', method: 'set', args: ['docs.1.city', 'newport'])

    it 'subscribedTo should test if a client id is subscribed to a given path', ->
      pubSub = @store._pubSub
      subscriber = '100'
      pubSub.subscribe subscriber, ['docs.1'], ->
        expect(pubSub.subscribedTo subscriber, 'docs.2').to.be.false
        expect(pubSub.subscribedTo subscriber, 'docs.1').to.be.true
        expect(pubSub.subscribedTo subscriber, 'docs.1.length').to.be.true
