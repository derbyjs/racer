{expect} = require '../util'
{Model} = require '../../lib/racer'
transaction = require '../../lib/transaction'
{mockSocketEcho, mockSocketModel} = require '../util/model'

mirrorTest = (done, init, callback) ->
  mirror = new Model
  mirror._commit = ->
  [model, sockets] = mockSocketEcho 0, unconnected: true

  model.on 'mutator', (method, path, {0: args}) ->
    args = JSON.parse JSON.stringify args
    # console.log method, args
    mirror[method] args...
  [remoteModel] = mockSocketModel 1, 'txn', (txn) ->
    sockets._queue JSON.parse JSON.stringify txn

  if arguments.length == 3
    mirror._memory._data.world =
      model._memory._data.world =
        remoteModel._memory._data.world = init
  else
    callback = init

  callback model, remoteModel

  process.nextTick ->
    model.socket._connect()
  setTimeout ->
    expect(mirror.get()).to.specEql model.get()
    done()
  , 10

describe 'Model event patching', ->

  it 'mock should support synching txns on connect', (done) ->
    [model, sockets] = mockSocketEcho 0, unconnected: true
    model.set 'name', 'John'
    sockets._queue transaction.create
      id: '1.0', method: 'set', args: ['color', 'green']

    model.socket._connect()
    setTimeout ->
      expect(model.get()).to.eql
        color: 'green'
        name: 'John'
      done()
    , 10

  it 'conflicting txn from server should be applied first', (done) ->
    [model, sockets] = mockSocketEcho 0, unconnected: true
    model.set 'name', 'John'
    sockets._queue transaction.create
      id: '1.0', method: 'set', args: ['name', 'Sue']

    model.socket._connect()
    setTimeout ->
      expect(model.get()).to.eql name: 'John'
      done()
    , 10

  it 'set on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.set 'name', 'John'
      model.set 'name', 'Sue'

  it 'set on parent', (done) ->
    mirrorTest done, (model, remote) ->
      remote.set 'user.name', 'John'
      model.set 'user', {}

  it 'set on child', (done) ->
    mirrorTest done, (model, remote) ->
      remote.set 'user', {}
      model.set 'user.name', 'John'

  it 'set and del on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.del 'name'
      model.set 'name', 'John'

  it 'set and push on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.push 'items', 'a'
      model.set 'items', []

  it 'pushes on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.push 'items', 'a', 'b', 'c'
      remote.push 'items', 'd'
      model.push 'items', 'x', 'y', 'z'
      model.push 'items', 'm', 'n'

  it 'unshifts on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.unshift 'items', 'a', 'b', 'c'
      remote.unshift 'items', 'd'
      model.unshift 'items', 'x', 'y', 'z'
      model.unshift 'items', 'm', 'n'

  it 'inserts on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.insert 'items', 0, 'a', 'b', 'c'
      remote.insert 'items', 1, 'd'
      model.insert 'items', 0, 'x', 'y', 'z'
      model.insert 'items', 3, 'm', 'n'

  it 'push & pop on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.push 'items', 'a', 'b', 'c'
      remote.pop 'items'
      model.push 'items', 'x'
      model.pop 'items'

  it 'moves on same path', (done) ->
    mirrorTest done, items: [
      {a: 0}
      {b: 1}
      {c: 2}
      {d: 3}
    ], (model, remote) ->
      remote.move 'items', 0, 3
      model.move 'items', 3, 0

  it 'moves on same path reverse', (done) ->
    mirrorTest done, items: [
      {a: 0}
      {b: 1}
      {c: 2}
      {d: 3}
    ], (model, remote) ->
      remote.move 'items', 3, 0
      model.move 'items', 0, 3

  it 'push, move, & pop on same path', (done) ->
    mirrorTest done, (model, remote) ->
      remote.push 'items', 'a', 'b', 'c'
      remote.move 'items', 1, 0, 2
      remote.pop 'items'
      model.push 'items', 'x', 'y'
      model.move 'items', 0, 1, 1
      model.pop 'items'

  it 'remove both local and remote', (done) ->
    mirrorTest done, {items: ['x']}, (model, remote) ->
      remote.remove 'items', 0
      model.remove 'items', 0

  it 'push & set on array index remote', (done) ->
    mirrorTest done, (model, remote) ->
      remote.push 'items', 1
      remote.set 'items.0', 'x'
      model.push 'items', 2

  it 'push & set on array index local', (done) ->
    mirrorTest done, (model, remote) ->
      remote.push 'items', 1
      model.push 'items', 0
      model.set 'items.0', 'x'

  it 'remote set & local push on array child', (done) ->
    mirrorTest done, {items: []}, (model, remote) ->
      remote.set 'items.0.name', 'x'
      model.push 'items', {name: 2}

  it 'remote push & local set on array child', (done) ->
    mirrorTest done, {items: []}, (model, remote) ->
      remote.push 'items', {name: 2}
      model.set 'items.0.name', 'x'

  it 'remote del & local move on array child', (done) ->
    mirrorTest done, {items: [1, 2, 3]}, (model, remote) ->
      remote.remove 'items', 0
      model.move 'items', 0, 2

  it 'remote push & set on array child', (done) ->
    mirrorTest done, {items: []}, (model, remote) ->
      remote.push 'items', {name: 1}
      remote.set 'items.0.name', 'x'
      model.push 'items', {name: 2}

  it 'local push & set on array child', (done) ->
    mirrorTest done, (model, remote) ->
      remote.push 'items', {name: 1}
      model.push 'items', {name: 0}
      model.set 'items.0.name', 'x'

  it 'local push & nested set on array child', (done) ->
    mirrorTest done, (model, remote) ->
      remote.push 'items', {name: 1}
      model.push 'items', {name: 0}
      model.set 'items.0.stuff.name', 'x'

  it 'local push & del on array child', (done) ->
    mirrorTest done, (model, remote) ->
      remote.push 'items', {name: 1}
      model.push 'items', {name: 0}
      model.del 'items.0.name'

  it 'local push & nested del on array child', (done) ->
    mirrorTest done, {items: [{stuff: {name: 2}}]}, (model, remote) ->
      remote.unshift 'items', {name: 1}
      model.del 'items.0.stuff.name'
