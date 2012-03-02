{expect, calls} = require '../util'
{BrowserModel: Model} = require '../util/model'

describe 'Model.refList', ->

  it 'should support getting', ->
    model = new Model
    model.set 'items',
      1: {id: 1, val: 'a'}
      2: {id: 2, val: 'b'}
      3: {id: 3, val: 'c'}
    model.set 'map', [3, 1]
    model.refList '_list', 'items', 'map'

    expect(model.get '_list').to.eql [{id: 3, val: 'c'}, {id: 1, val: 'a'}]
    expect(model.get '_list.0').to.eql {id: 3, val: 'c'}

    # Test changing the key object
    model.set 'map', ['1', '2']
    expect(model.get '_list').to.eql [{id: 1, val: 'a'}, {id: 2, val: 'b'}]

    # Test changing referenced objects
    model.set 'items',
      1: {id: 1, val: 'x'}
      2: {id: 2, val: 'y'}
      3: {id: 3, val: 'z'}
    expect(model.get '_list').to.eql [{id: 1, val: 'x'}, {id: 2, val: 'y'}]

  it 'should support getting undefined children', ->
    model = new Model
    model.refList '_list', 'items', 'map'

    expect(model.get '_list').to.equal undefined
    expect(model.get '_list.0').to.equal undefined
    expect(model.get '_list.0.stuff').to.equal undefined

  it 'should support set of children', ->
    model = new Model
    model.refList '_list', 'items', 'map'

    model.set '_list.0', {id: 3, val: 'c'}
    model.set '_list.1', {id: 1, val: 'a'}
    expect(Array.isArray model.get('map')).to.be.true
    expect(model.get 'map').to.specEql [3, 1]
    expect(model.get 'items').to.specEql
      1: {id: 1, val: 'a'}
      3: {id: 3, val: 'c'}

    model.set '_list.1', {id: 1, val: 'aa'}
    expect(model.get 'map').to.specEql [3, 1]
    expect(model.get 'items').to.specEql
      1: {id: 1, val: 'aa'}
      3: {id: 3, val: 'c'}

    # An id should be automatically created by model.id
    model.set '_list.2', obj = {val: 'x'}
    id = obj.id
    expect(model.get "items.#{id}").to.specEql {val: 'x', id}

  it 'should support del of children', ->
    model = new Model
    model.set 'items',
      1: {id: 1, val: 'a'}
      3: {id: 3, val: 'c'}
    model.set 'map', [3, 1]
    model.refList '_list', 'items', 'map'

    model.del '_list.0'
    expect(model.get 'map').to.specEql [undefined, 1]
    expect(model.get 'items').to.specEql
      1: {id: 1, val: 'a'}

  it 'should support operations on children', ->
    model = new Model
    model.set 'items',
      1: {id: 1, val: 'a'}
      3: {id: 3, val: 'c'}
    model.set 'map', [3, 1]
    model.refList '_list', 'items', 'map'

    model.set '_list.0.x', 'added'
    model.push '_list.0.arr', 7
    expected = {id: 3, val: 'c', x: 'added', arr: [7]}
    expect(model.get '_list.0').to.specEql expected
    expect(model.get 'items.3').to.specEql expected

  it 'should support push', ->
    model = new Model
    model.refList '_list', 'items', 'map'

    len = model.push '_list', {id: 3, val: 'c'}
    expect(len).to.eql 1
    expect(model.get '_list').to.specEql [{id: 3, val: 'c'}]
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
    expect(model.get 'map').to.specEql [3]

    len = model.push '_list', {id: 1, val: 'a'}, {id: 2, val: 'b'}
    expect(len).to.eql 3
    expect(model.get '_list').to.specEql [
      {id: 3, val: 'c'}
      {id: 1, val: 'a'}
      {id: 2, val: 'b'}
    ]
    expect(model.get 'items').to.specEql
      1: {id: 1, val: 'a'}
      2: {id: 2, val: 'b'}
      3: {id: 3, val: 'c'}
    expect(model.get 'map').to.specEql [3, 1, 2]

    # An id should be automatically created by model.id
    model.push '_list', obj = {val: 'x'}
    id = obj.id
    expect(model.get "items.#{id}").to.specEql {val: 'x', id}
    expect(model.get 'map').to.specEql [3, 1, 2, id]

  it 'should support unshift', ->
    model = new Model
    model.refList '_list', 'items', 'map'

    len = model.unshift '_list', {id: 3, val: 'c'}
    expect(len).to.eql 1
    expect(model.get '_list').to.specEql [{id: 3, val: 'c'}]
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
    expect(model.get 'map').to.specEql [3]

    len = model.unshift '_list', {id: 1, val: 'a'}, {id: 2, val: 'b'}
    expect(len).to.eql 3
    expect(model.get '_list').to.specEql [
      {id: 1, val: 'a'}
      {id: 2, val: 'b'}
      {id: 3, val: 'c'}
    ]
    expect(model.get 'items').to.specEql
      1: {id: 1, val: 'a'}
      2: {id: 2, val: 'b'}
      3: {id: 3, val: 'c'}
    expect(model.get 'map').to.specEql [1, 2, 3]

    # An id should be automatically created by model.id
    model.unshift '_list', obj = {val: 'x'}
    id = obj.id
    expect(model.get "items.#{id}").to.specEql {val: 'x', id}
    expect(model.get 'map').to.specEql [id, 1, 2, 3]

  it 'should support insert', ->
    model = new Model
    model.refList '_list', 'items', 'map'

    len = model.insert '_list', 0, {id: 1, val: 'a'}, {id: 2, val: 'b'}
    expect(len).to.eql 2
    expect(model.get '_list').to.specEql [
      {id: 1, val: 'a'}
      {id: 2, val: 'b'}
    ]
    expect(model.get 'items').to.specEql
      1: {id: 1, val: 'a'}
      2: {id: 2, val: 'b'}
    expect(model.get 'map').to.specEql [1, 2]

    len = model.insert '_list', 1, {id: 3, val: 'c'}
    expect(len).to.eql 3
    expect(model.get '_list').to.specEql [
      {id: 1, val: 'a'}
      {id: 3, val: 'c'}
      {id: 2, val: 'b'}
    ]
    expect(model.get 'items').to.specEql
      1: {id: 1, val: 'a'}
      2: {id: 2, val: 'b'}
      3: {id: 3, val: 'c'}
    expect(model.get 'map').to.specEql [1, 3, 2]

    # An id should be automatically created by model.id
    model.insert '_list', 2, obj = {val: 'x'}
    id = obj.id
    expect(model.get "items.#{id}").to.specEql {val: 'x', id}
    expect(model.get 'map').to.specEql [1, 3, id, 2]

  it 'should support pop', ->
    model = new Model
    model.set 'items',
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
    model.set 'map', [3, 7]
    model.refList '_list', 'items', 'map'

    key = model.pop '_list'
    # Pop returns the popped off key, not the
    # object that it referenced
    expect(key).to.eql 7
    expect(model.get '_list').to.specEql [
      {id: 3, val: 'c'}
    ]
    # Pop does not delete the underlying object
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
    expect(model.get 'map').to.specEql [3]

  it 'should support shift', ->
    model = new Model
    model.set 'items',
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
    model.set 'map', [3, 7]
    model.refList '_list', 'items', 'map'

    key = model.shift '_list'
    # Shift returns the popped off key, not the
    # object that it referenced
    expect(key).to.eql 3
    expect(model.get '_list').to.specEql [
      {id: 7, val: 'g'}
    ]
    # Shift does not delete the underlying object
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
    expect(model.get 'map').to.specEql [7]

  it 'should support remove', ->
    model = new Model
    model.set 'items',
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    model.set 'map', [3, 7, 8]
    model.refList '_list', 'items', 'map'

    removed = model.remove '_list', 1
    # Remove returns the removed keys, not the
    # referenced objects
    expect(removed).to.eql [7]
    expect(model.get '_list').to.specEql [
      {id: 3, val: 'c'}
      {id: 8, val: 'h'}
    ]
    # Remove does not delete the underlying objects
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    expect(model.get 'map').to.specEql [3, 8]

    removed = model.remove '_list', 0, 2
    # Remove returns the removed keys, not the
    # referenced objects
    expect(removed).to.eql [3, 8]
    expect(model.get '_list').to.specEql []
    # Remove does not delete the underlying objects
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    expect(model.get 'map').to.specEql []

  it 'should support move', ->
    model = new Model
    model.set 'items',
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    model.set 'map', [3, 7, 8]
    model.refList '_list', 'items', 'map'

    moved = model.move '_list', 1, 0
    # Move returns the moved key, not the
    # referenced object
    expect(moved).to.eql [7]
    expect(model.get '_list').to.specEql [
      {id: 7, val: 'g'}
      {id: 3, val: 'c'}
      {id: 8, val: 'h'}
    ]
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    expect(model.get 'map').to.specEql [7, 3, 8]

    moved = model.move '_list', 0, 2
    # Move returns the moved key, not the
    # referenced object
    expect(moved).to.eql [7]
    expect(model.get '_list').to.specEql [
      {id: 3, val: 'c'}
      {id: 8, val: 'h'}
      {id: 7, val: 'g'}
    ]
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    expect(model.get 'map').to.specEql [3, 8, 7]

  it 'should support insert by id', ->
    model = new Model
    model.set 'items',
      1: {id: 1, val: 'a'}
      2: {id: 2, val: 'b'}
    model.set 'map', [1, 2]
    model.refList '_list', 'items', 'map'

    len = model.insert '_list', {id: 2}, {id: 3, val: 'c'}
    expect(len).to.eql 3
    expect(model.get '_list').to.specEql [
      {id: 1, val: 'a'}
      {id: 3, val: 'c'}
      {id: 2, val: 'b'}
    ]
    expect(model.get 'items').to.specEql
      1: {id: 1, val: 'a'}
      2: {id: 2, val: 'b'}
      3: {id: 3, val: 'c'}
    expect(model.get 'map').to.specEql [1, 3, 2]

  it 'should support remove by id', ->
    model = new Model
    model.set 'items',
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    model.set 'map', [3, 7, 8]
    model.refList '_list', 'items', 'map'

    removed = model.remove '_list', {id: 7}
    # Remove returns the removed keys, not the
    # referenced objects
    expect(removed).to.eql [7]
    expect(model.get '_list').to.specEql [
      {id: 3, val: 'c'}
      {id: 8, val: 'h'}
    ]
    # Remove does not delete the underlying objects
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    expect(model.get 'map').to.specEql [3, 8]

    removed = model.remove '_list', {id: 3}, 2
    # Remove returns the removed keys, not the
    # referenced objects
    expect(removed).to.eql [3, 8]
    expect(model.get '_list').to.specEql []
    # Remove does not delete the underlying objects
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    expect(model.get 'map').to.specEql []

  it 'should support move by id', ->
    model = new Model
    model.set 'items',
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    model.set 'map', [3, 7, 8]
    model.refList '_list', 'items', 'map'

    moved = model.move '_list', {id: 7}, 0
    # Move returns the moved key, not the
    # referenced object
    expect(moved).to.eql [7]
    expect(model.get '_list').to.specEql [
      {id: 7, val: 'g'}
      {id: 3, val: 'c'}
      {id: 8, val: 'h'}
    ]
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    expect(model.get 'map').to.specEql [7, 3, 8]

    moved = model.move '_list', {id: 7}, {id: 8}
    # Move returns the moved key, not the
    # referenced object
    expect(moved).to.eql [7]
    expect(model.get '_list').to.specEql [
      {id: 3, val: 'c'}
      {id: 8, val: 'h'}
      {id: 7, val: 'g'}
    ]
    expect(model.get 'items').to.specEql
      3: {id: 3, val: 'c'}
      7: {id: 7, val: 'g'}
      8: {id: 8, val: 'h'}
    expect(model.get 'map').to.specEql [3, 8, 7]

  it 'should emit on push', calls 2, (done) ->
    model = new Model
    model.refList '_list', 'items', 'map'

    model.on 'push', '_list', (value, len) ->
      expect(value).to.eql {id: 3, val: 'c'}
      expect(len).to.eql 1
      done()
    model.on 'push', 'map', (id, len) ->
      expect(id).to.eql 3
      expect(len).to.eql 1
      done()
    model.push '_list', {id: 3, val: 'c'}

  it 'should emit on set of children', calls 2, (done) ->
    model = new Model
    model.refList '_list', 'items', 'map'

    model.on 'set', '_list.*', cb = (index, value) ->
      expect(index).to.eql '0'
      expect(value).to.eql {id: 3, val: 'c'}
      done()
    model.on 'set', 'items.*', cb = (id, value) ->
      expect(id).to.eql '3'
      expect(value).to.eql {id: 3, val: 'c'}
      done()
    model.set '_list.0', {id: 3, val: 'c'}

  it 'should emit on set under child', calls 2, (done) ->
    model = new Model
    model.refList '_list', 'items', 'map'
    model.set 'items',
      3: {id: 3, val: 'c'}
    model.set 'map', [3]

    model.on 'set', '_list.0.name', cb = (value) ->
      expect(value).to.eql 'howdy'
      done()
    model.on 'set', 'items.3.name', cb = (value) ->
      expect(value).to.eql 'howdy'
      done()
    model.set '_list.0.name', 'howdy'
