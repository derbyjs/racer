{expect} = require '../util'
Model = require './MockConnectionModel'

mutationEvents = (createModels) ->

  describe 'set', ->
    it 'can raise events registered on array indices', (done) ->
      [local, remote] = createModels()
      local.set 'array', [0, 1, 2, 3, 4], ->

      remote.on 'change', 'array.0', (value, previous) ->
        expect(value).to.equal 1 
        expect(previous).to.equal 0
        done()

      local.set 'array.0', 1

  describe 'move', ->

    it 'can move an item from the end to the beginning of the array', (done) ->
      [local, remote] = createModels()
      local.set 'array', [0, 1, 2, 3, 4]

      remote.on 'move', '**', (captures..., from, to, howMany, passed) ->
        expect(from).to.equal 4
        expect(to).to.equal 0
        done()

      local.move 'array', 4, 0, 1

    it 'can swap the first two items in the array', (done) ->
      [local, remote] = createModels()
      local.set 'array', [0, 1, 2, 3, 4], ->

      remote.on 'move', '**', (captures..., from, to, howMany, passed) ->
        expect(from).to.equal 1
        expect(to).to.equal 0
        done()

      local.move 'array', 1, 0, 1, ->

    it 'can move an item from the begnning to the end of the array', (done) ->
      [local, remote] = createModels()
      local.set 'array', [0, 1, 2, 3, 4], ->

      remote.on 'move', '**', (captures..., from, to, howMany, passed) ->
        expect(from).to.equal 0
        expect(to).to.equal 4
        done()

      # note that destination is index after removal of item
      local.move 'array', 0, 4, 1, ->

    it 'supports a negative destination index of -1 (for last)', (done) ->
      [local, remote] = createModels()
      local.set 'array', [0, 1, 2, 3, 4], ->

      remote.on 'move', '**', (captures, from, to, howMany, passed) ->
        expect(from).to.equal 0
        expect(to).to.equal 4
        done()

      local.move 'array', 0, -1, 1, ->

    it 'supports a negative source index of -1 (for last)', (done) ->
      [local, remote] = createModels()
      local.set 'array', [0, 1, 2, 3, 4], ->

      remote.on 'move', '**', (captures..., from, to, howMany, passed) ->
        expect(from).to.equal 4
        expect(to).to.equal 2
        done()

      local.move 'array', -1, 2, 1, ->

    it 'can move several items mid-array, with an event for each', (done) ->
      [local, remote] = createModels()
      local.set 'array', [0, 1, 2, 3, 4], ->

      events = 0
      # When going through ShareJS, the single howMany > 1 move is split into
      # lots of howMany==1 moves
      remote.on 'move', '**', (captures..., from, to, howMany, passed) ->
        expect(from).to.equal 1
        expect(to).to.equal 4
        done() if ++events == 2

      # note that destination is index after removal of items
      local.move 'array', 1, 3, 2, ->

describe 'Model events', ->

  describe 'mutator events', ->

    it 'calls earlier listeners in the order of mutations', (done) ->
      model = (new Model).at '_page'
      expectedPaths = ['a', 'b', 'c']
      model.on 'change', '**', (path) ->
        expect(path).to.equal expectedPaths.shift()
        done() unless expectedPaths.length
      model.on 'change', 'a', ->
        model.set 'b', 2
      model.on 'change', 'b', ->
        model.set 'c', 3
      model.set 'a', 1

    it 'calls later listeners in the order of mutations', (done) ->
      model = (new Model).at '_page'
      model.on 'change', 'a', ->
        model.set 'b', 2
      model.on 'change', 'b', ->
        model.set 'c', 3
      expectedPaths = ['a', 'b', 'c']
      model.on 'change', '**', (path) ->
        expect(path).to.equal expectedPaths.shift()
        done() unless expectedPaths.length
      model.set 'a', 1

  describe 'remote events', ->
    createModels = ->
      localModel = new Model()
      localModel.createConnection()
      remoteModel = new Model()
      remoteModel.createConnection()

      # Link the two models explicitly, so we can test event content
      localDoc = localModel.getOrCreateDoc 'colors', 'green'
      remoteDoc = remoteModel.getOrCreateDoc 'colors', 'green'
      localDoc.shareDoc.on 'op', (op, isLocal) ->
        remoteDoc._onOp op

      return [localModel.scope('colors.green'), remoteModel.scope('colors.green')]

    mutationEvents createModels
