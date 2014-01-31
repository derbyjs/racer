{expect} = require '../util'
Model = require '../../lib/Model'
RemoteDoc = require '../../lib/Model/RemoteDoc'
docs = require './docs'
share = require 'share'

# Mock up a connection with a fake socket
Model.prototype._createConnection = ->
  socketMock =
    send: (message) ->
    close: ->
    onmessage: ->
    onclose: ->
    onerror: ->
    onopen: ->
    onconnecting: ->
  @root.socket = socketMock
  @root.shareConnection = new share.client.Connection(socketMock)
  @_createChannel()

describe 'RemoteDoc', ->

  createModel = ->
    model = new Model
    model._createConnection()
    model.data =
      colors: {}
    model

  remote = null
  createDoc = ->
    local = new RemoteDoc createModel(), 'colors', 'green'
    remote = new RemoteDoc createModel(), 'colors', 'green'
    # Link the two models explicitly, so we can test event content
    local.shareDoc.on 'op', (op, isLocal) ->
      remote._onOp(op)
    local

  describe 'create', ->
    it 'should set the collectionName and id properties', ->
      doc = createDoc()
      expect(doc.collectionName).to.equal 'colors'
      expect(doc.id).to.equal 'green'

  docs createDoc

  describe 'move', ->

    it 'can move an item from the end to the beginning of the array', (done)->
      doc = createDoc()
      doc.set ['array'], [0, 1, 2, 3, 4], ->

      remote.model.on 'move', (captures, [from, to, howMany, passed]) ->
        expect(from).to.equal 4
        expect(to).to.equal 0
        done()

      moved = doc.move ['array'], 4, 0, 1, ->
      expect(moved).eql [4]
      expect(doc.get()).eql {array: [4, 0, 1, 2, 3]}

    it 'can swap the first two items in the array', (done) ->
      doc = createDoc()
      doc.set ['array'], [0, 1, 2, 3, 4], ->

      remote.model.on 'move', (captures, [from, to, howMany, passed]) ->
        expect(from).to.equal 1
        expect(to).to.equal 0
        done()

      moved = doc.move ['array'], 1, 0, 1, ->
      expect(moved).eql [1]
      expect(doc.get()).eql {array: [1, 0, 2, 3, 4]}

    it 'can move an item from the begnning to the end of the array', (done) ->
      doc = createDoc()
      doc.set ['array'], [0, 1, 2, 3, 4], ->

      remote.model.on 'move', (captures, [from, to, howMany, passed]) ->
        expect(from).to.equal 0
        expect(to).to.equal 4
        done()

      # note that destination is index after removal of item
      moved = doc.move ['array'], 0, 4, 1, ->
      expect(moved).eql [0]
      expect(doc.get()).eql {array: [1, 2, 3, 4, 0]}

    it 'supports a negative destination index of -1 (for pre-last)', (done) ->
      doc = createDoc()
      doc.set ['array'], [0, 1, 2, 3, 4], ->

      remote.model.on 'move', (captures, [from, to, howMany, passed]) ->
        expect(from).to.equal 0
        expect(to).to.equal -1
        done()

      moved = doc.move ['array'], 0, -1, 1, ->
      expect(moved).eql [0]
      expect(doc.get()).eql {array: [1, 2, 3, 0, 4]}

    it 'supports a negative source index of -1 (for pre-last)', (done) ->
      doc = createDoc()
      doc.set ['array'], [0, 1, 2, 3, 4], ->

      remote.model.on 'move', (captures, [from, to, howMany, passed]) ->
        expect(from).to.equal -1
        expect(to).to.equal 2
        done()

      moved = doc.move ['array'], -1, 2, 1, ->
      expect(moved).eql [3]
      expect(doc.get()).eql {array: [0, 1, 3, 2, 4]}

    it 'can move several items mid-array, with an event for each', (done) ->
      doc = createDoc()
      doc.set ['array'], [0, 1, 2, 3, 4], ->

      events = 0
      # the single howMany > 1 move is split into lots of howMany==1 moves
      remote.model.on 'move', (captures, [from, to, howMany, passed]) ->
        expect(from).to.equal 1
        expect(to).to.equal 4
        if ++events == 2
          done()

      # note that destination is index after removal of items
      moved = doc.move ['array'], 1, 3, 2, ->
      expect(moved).eql [1, 2]
      expect(doc.get()).eql {array: [0, 3, 4, 1, 2]}

