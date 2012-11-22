{expect, calls} = require '../util'
{BrowserModel: Model} = require '../util/model'

describe 'Model.refList', ->

  it 'should support getting', ->
    model = new Model
    model.set 'items',
      'x1': {id: 'x1', val: 'a'}
      'x2': {id: 'x2', val: 'b'}
      'x3': {id: 'x3', val: 'c'}
    model.set '_map', ['x3', 'x1']
    model.refList '_list', 'items', '_map'

    expect(model.get '_list').to.eql [{id: 'x3', val: 'c'}, {id: 'x1', val: 'a'}]
    expect(model.get '_list.0').to.eql {id: 'x3', val: 'c'}
    expect(model.get '_list.length').to.eql 2

    # Test changing the key object
    model.set '_map', ['x1', 'x2']
    expect(model.get '_list').to.eql [{id: 'x1', val: 'a'}, {id: 'x2', val: 'b'}]

    # Test changing referenced objects
    model.set 'items',
      'x1': {id: 'x1', val: 'x'}
      'x2': {id: 'x2', val: 'y'}
      'x3': {id: 'x3', val: 'z'}
    expect(model.get '_list').to.eql [{id: 'x1', val: 'x'}, {id: 'x2', val: 'y'}]

  it 'should support getting undefined children', ->
    model = new Model
    model.refList '_list', 'items', '_map'

    expect(model.get '_list').to.eql []
    expect(model.get '_list.0').to.equal undefined
    expect(model.get '_list.0.stuff').to.equal undefined

  it 'should support set of children', ->
    model = new Model
    model.refList '_list', 'items', '_map'

    model.set '_list.0', {id: 'x3', val: 'c'}
    model.set '_list.1', {id: 'x1', val: 'a'}
    expect(Array.isArray model.get('_map')).to.be.true
    expect(model.get '_map').to.specEql ['x3', 'x1']
    expect(model.get 'items').to.specEql
      'x1': {id: 'x1', val: 'a'}
      'x3': {id: 'x3', val: 'c'}

    model.set '_list.1', {id: 'x1', val: 'aa'}
    expect(model.get '_map').to.specEql ['x3', 'x1']
    expect(model.get 'items').to.specEql
      'x1': {id: 'x1', val: 'aa'}
      'x3': {id: 'x3', val: 'c'}

    # An id should be automatically created by model.id
    model.set '_list.2', obj = {val: 'x'}
    id = obj.id
    expect(model.get "items.#{id}").to.specEql {val: 'x', id}

  it 'should support del of children', ->
    model = new Model
    model.set 'items',
      'x1': {id: 'x1', val: 'a'}
      'x3': {id: 'x3', val: 'c'}
    model.set '_map', ['x3', 'x1']
    model.refList '_list', 'items', '_map'

    model.del '_list.0'
    expect(model.get '_map').to.specEql [undefined, 'x1']
    expect(model.get 'items').to.specEql
      'x1': {id: 'x1', val: 'a'}

  it 'should support operations on children', ->
    model = new Model
    model.set 'items',
      'x1': {id: 'x1', val: 'a'}
      'x3': {id: 'x3', val: 'c'}
    model.set '_map', ['x3', 'x1']
    model.refList '_list', 'items', '_map'

    model.set '_list.0.x', 'added'
    model.push '_list.0.arr', 7
    expected = {id: 'x3', val: 'c', x: 'added', arr: [7]}
    expect(model.get '_list.0').to.specEql expected
    expect(model.get 'items.x3').to.specEql expected

  it 'should support push', ->
    model = new Model
    model.refList '_list', 'items', '_map'

    len = model.push '_list', {id: 'x3', val: 'c'}
    expect(len).to.eql 1
    expect(model.get '_list').to.specEql [{id: 'x3', val: 'c'}]
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
    expect(model.get '_map').to.specEql ['x3']

    len = model.push '_list', {id: 'x1', val: 'a'}, {id: 'x2', val: 'b'}
    expect(len).to.eql 3
    expect(model.get '_list').to.specEql [
      {id: 'x3', val: 'c'}
      {id: 'x1', val: 'a'}
      {id: 'x2', val: 'b'}
    ]
    expect(model.get 'items').to.specEql
      'x1': {id: 'x1', val: 'a'}
      'x2': {id: 'x2', val: 'b'}
      'x3': {id: 'x3', val: 'c'}
    expect(model.get '_map').to.specEql ['x3', 'x1', 'x2']

    # An id should be automatically created by model.id
    model.push '_list', obj = {val: 'x'}
    id = obj.id
    expect(model.get "items.#{id}").to.specEql {val: 'x', id}
    expect(model.get '_map').to.specEql ['x3', 'x1', 'x2', id]

  it 'should support unshift', ->
    model = new Model
    model.refList '_list', 'items', '_map'

    len = model.unshift '_list', {id: 'x3', val: 'c'}
    expect(len).to.eql 1
    expect(model.get '_list').to.specEql [{id: 'x3', val: 'c'}]
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
    expect(model.get '_map').to.specEql ['x3']

    len = model.unshift '_list', {id: 'x1', val: 'a'}, {id: 'x2', val: 'b'}
    expect(len).to.eql 3
    expect(model.get '_list').to.specEql [
      {id: 'x1', val: 'a'}
      {id: 'x2', val: 'b'}
      {id: 'x3', val: 'c'}
    ]
    expect(model.get 'items').to.specEql
      'x1': {id: 'x1', val: 'a'}
      'x2': {id: 'x2', val: 'b'}
      'x3': {id: 'x3', val: 'c'}
    expect(model.get '_map').to.specEql ['x1', 'x2', 'x3']

    # An id should be automatically created by model.id
    model.unshift '_list', obj = {val: 'x'}
    id = obj.id
    expect(model.get "items.#{id}").to.specEql {val: 'x', id}
    expect(model.get '_map').to.specEql [id, 'x1', 'x2', 'x3']

  it 'should support insert', ->
    model = new Model
    model.refList '_list', 'items', '_map'

    len = model.insert '_list', 0, {id: 'x1', val: 'a'}, {id: 'x2', val: 'b'}
    expect(len).to.eql 2
    expect(model.get '_list').to.specEql [
      {id: 'x1', val: 'a'}
      {id: 'x2', val: 'b'}
    ]
    expect(model.get 'items').to.specEql
      'x1': {id: 'x1', val: 'a'}
      'x2': {id: 'x2', val: 'b'}
    expect(model.get '_map').to.specEql ['x1', 'x2']

    len = model.insert '_list', 1, {id: 'x3', val: 'c'}
    expect(len).to.eql 3
    expect(model.get '_list').to.specEql [
      {id: 'x1', val: 'a'}
      {id: 'x3', val: 'c'}
      {id: 'x2', val: 'b'}
    ]
    expect(model.get 'items').to.specEql
      'x1': {id: 'x1', val: 'a'}
      'x2': {id: 'x2', val: 'b'}
      'x3': {id: 'x3', val: 'c'}
    expect(model.get '_map').to.specEql ['x1', 'x3', 'x2']

    # An id should be automatically created by model.id
    model.insert '_list', 2, obj = {val: 'x'}
    id = obj.id
    expect(model.get "items.#{id}").to.specEql {val: 'x', id}
    expect(model.get '_map').to.specEql ['x1', 'x3', id, 'x2']

  it 'should support pop', ->
    model = new Model
    model.set 'items',
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
    model.set '_map', ['x3', 'x7']
    model.refList '_list', 'items', '_map'

    key = model.pop '_list'
    # Pop returns the popped off key, not the
    # object that it referenced
    expect(key).to.eql 'x7'
    expect(model.get '_list').to.specEql [
      {id: 'x3', val: 'c'}
    ]
    # Pop does not delete the underlying object
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
    expect(model.get '_map').to.specEql ['x3']

  it 'should support shift', ->
    model = new Model
    model.set 'items',
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
    model.set '_map', ['x3', 'x7']
    model.refList '_list', 'items', '_map'

    key = model.shift '_list'
    # Shift returns the popped off key, not the
    # object that it referenced
    expect(key).to.eql 'x3'
    expect(model.get '_list').to.specEql [
      {id: 'x7', val: 'g'}
    ]
    # Shift does not delete the underlying object
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
    expect(model.get '_map').to.specEql ['x7']

  it 'should support remove', ->
    model = new Model
    model.set 'items',
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    model.set '_map', ['x3', 'x7', 'x8']
    model.refList '_list', 'items', '_map'

    removed = model.remove '_list', 1
    # Remove returns the removed keys, not the
    # referenced objects
    expect(removed).to.eql ['x7']
    expect(model.get '_list').to.specEql [
      {id: 'x3', val: 'c'}
      {id: 'x8', val: 'h'}
    ]
    # Remove does not delete the underlying objects
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    expect(model.get '_map').to.specEql ['x3', 'x8']

    removed = model.remove '_list', 0, 2
    # Remove returns the removed keys, not the
    # referenced objects
    expect(removed).to.eql ['x3', 'x8']
    expect(model.get '_list').to.specEql []
    # Remove does not delete the underlying objects
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    expect(model.get '_map').to.specEql []

  it 'should support move', ->
    model = new Model
    model.set 'items',
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    model.set '_map', ['x3', 'x7', 'x8']
    model.refList '_list', 'items', '_map'

    moved = model.move '_list', 1, 0
    # Move returns the moved key, not the
    # referenced object
    expect(moved).to.eql ['x7']
    expect(model.get '_list').to.specEql [
      {id: 'x7', val: 'g'}
      {id: 'x3', val: 'c'}
      {id: 'x8', val: 'h'}
    ]
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    expect(model.get '_map').to.specEql ['x7', 'x3', 'x8']

    moved = model.move '_list', 0, 2
    # Move returns the moved key, not the
    # referenced object
    expect(moved).to.eql ['x7']
    expect(model.get '_list').to.specEql [
      {id: 'x3', val: 'c'}
      {id: 'x8', val: 'h'}
      {id: 'x7', val: 'g'}
    ]
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    expect(model.get '_map').to.specEql ['x3', 'x8', 'x7']

  it 'should support insert by id', ->
    model = new Model
    model.set 'items',
      'x1': {id: 'x1', val: 'a'}
      'x2': {id: 'x2', val: 'b'}
    model.set '_map', ['x1', 'x2']
    model.refList '_list', 'items', '_map'

    len = model.insert '_list', {id: 'x2'}, {id: 'x3', val: 'c'}
    expect(len).to.eql 3
    expect(model.get '_list').to.specEql [
      {id: 'x1', val: 'a'}
      {id: 'x3', val: 'c'}
      {id: 'x2', val: 'b'}
    ]
    expect(model.get 'items').to.specEql
      'x1': {id: 'x1', val: 'a'}
      'x2': {id: 'x2', val: 'b'}
      'x3': {id: 'x3', val: 'c'}
    expect(model.get '_map').to.specEql ['x1', 'x3', 'x2']

  it 'should support remove by id', ->
    model = new Model
    model.set 'items',
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    model.set '_map', ['x3', 'x7', 'x8']
    model.refList '_list', 'items', '_map'

    removed = model.remove '_list', {id: 'x7'}
    # Remove returns the removed keys, not the
    # referenced objects
    expect(removed).to.eql ['x7']
    expect(model.get '_list').to.specEql [
      {id: 'x3', val: 'c'}
      {id: 'x8', val: 'h'}
    ]
    # Remove does not delete the underlying objects
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    expect(model.get '_map').to.specEql ['x3', 'x8']

    removed = model.remove '_list', {id: 'x3'}, 2
    # Remove returns the removed keys, not the
    # referenced objects
    expect(removed).to.eql ['x3', 'x8']
    expect(model.get '_list').to.specEql []
    # Remove does not delete the underlying objects
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    expect(model.get '_map').to.specEql []

  it 'should support move by id', ->
    model = new Model
    model.set 'items',
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    model.set '_map', ['x3', 'x7', 'x8']
    model.refList '_list', 'items', '_map'

    moved = model.move '_list', {id: 'x7'}, 0
    # Move returns the moved key, not the
    # referenced object
    expect(moved).to.eql ['x7']
    expect(model.get '_list').to.specEql [
      {id: 'x7', val: 'g'}
      {id: 'x3', val: 'c'}
      {id: 'x8', val: 'h'}
    ]
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    expect(model.get '_map').to.specEql ['x7', 'x3', 'x8']

    moved = model.move '_list', {id: 'x7'}, {id: 'x8'}
    # Move returns the moved key, not the
    # referenced object
    expect(moved).to.eql ['x7']
    expect(model.get '_list').to.specEql [
      {id: 'x3', val: 'c'}
      {id: 'x8', val: 'h'}
      {id: 'x7', val: 'g'}
    ]
    expect(model.get 'items').to.specEql
      'x3': {id: 'x3', val: 'c'}
      'x7': {id: 'x7', val: 'g'}
      'x8': {id: 'x8', val: 'h'}
    expect(model.get '_map').to.specEql ['x3', 'x8', 'x7']

  it 'should emit on push', calls 2, (done) ->
    model = new Model
    model.refList '_list', 'items', '_map'

    model.on 'push', '_list', (value, len) ->
      expect(value).to.eql {id: 'x3', val: 'c'}
      expect(len).to.eql 1
      done()
    model.on 'push', '_map', (id, len) ->
      expect(id).to.eql 'x3'
      expect(len).to.eql 1
      done()
    model.push '_list', {id: 'x3', val: 'c'}

  it 'should emit on set of children', calls 2, (done) ->
    model = new Model
    model.refList '_list', 'items', '_map'

    model.on 'set', '_list.*', (index, value) ->
      expect(index).to.eql '0'
      expect(value).to.eql {id: 'x3', val: 'c'}
      done()
    model.on 'set', 'items.*', (id, value) ->
      expect(id).to.eql 'x3'
      expect(value).to.eql {id: 'x3', val: 'c'}
      done()
    model.set '_list.0', {id: 'x3', val: 'c'}

  it 'should emit on set under child', calls 2, (done) ->
    model = new Model
    model.refList '_list', 'items', '_map'
    model.set 'items',
      'x3': {id: 'x3', val: 'c'}
    model.set '_map', ['x3']

    model.on 'set', '_list.0.name', (value) ->
      expect(value).to.eql 'howdy'
      done()
    model.on 'set', 'items.x3.name', (value) ->
      expect(value).to.eql 'howdy'
      done()
    model.set '_list.0.name', 'howdy'


  describe 'a ref pointing to a refList', ->
    it 'should emit on set under child', calls 2, (done) ->
      model = new Model
      model.refList '_list', 'items', '_map'
      model.ref '_ref', '_list'
      model.set 'items',
        'x3': {id: 'x3', val: 'c'}
      model.set '_map', ['x3']

      model.on 'set', '_list.0.name', (value) ->
        expect(value).to.eql 'howdy'
        done()
      model.on 'set', 'items.x3.name', (value) ->
        expect(value).to.eql 'howdy'
        done()
      model.set '_ref.0.name', 'howdy'

    it 'should not mess up assignment', ->
      model = new Model
      model.set 'profiles',
        a:
          id: 'a'
          roles:
            x:
              id: 'x'
          roleIds: ['x']

      model.ref '_profile', 'profiles.a'
      model.refList '_profile._roles', '_profile.roles', '_profile.roleIds'

      expect(model.get '_profile').to.specEql
        id: 'a'
        roles:
          x:
            id: 'x'
        roleIds: ['x']

    it 'should support length', ->
      model = new Model
      model.refList '_list', 'items', '_map'
      model.ref '_ref', '_list'
      model.set 'items',
        'x3': {id: 'x3', val: 'c'}
      model.set '_map', ['x3']
      expect(model.get '_ref.length').to.equal 1

    it 'should support push', ->
      model = new Model
      model.refList '_list', 'items', '_map'
      model.ref '_ref', '_list'

      len = model.push '_ref', {id: 'x3', val: 'c'}
      expect(len).to.eql 1
      expect(model.get '_ref').to.specEql [{id: 'x3', val: 'c'}]
      expect(model.get 'items').to.specEql
        'x3': {id: 'x3', val: 'c'}
      expect(model.get '_map').to.specEql ['x3']
