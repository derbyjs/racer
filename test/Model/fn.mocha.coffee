{expect} = require '../util'
Model = require '../../lib/Model'

describe 'fn', ->

  describe 'evaluate', ->

    it 'supports fn with a getter function', ->
      model = new Model
      model.fn 'sum', (a, b) -> a + b
      model.set '_nums.a', 2
      model.set '_nums.b', 4
      result = model.evaluate 'sum', '_nums.a', '_nums.b'
      expect(result).to.equal 6

    it 'supports fn with an object', ->
      model = new Model
      model.fn 'sum',
        get: (a, b) -> a + b
      model.set '_nums.a', 2
      model.set '_nums.b', 4
      result = model.evaluate 'sum', '_nums.a', '_nums.b'
      expect(result).to.equal 6

    it 'supports fn with variable arguments', ->
      model = new Model
      model.fn 'sum', (args...) ->
        sum = 0
        sum += arg for arg in args
        return sum
      model.set '_nums.a', 2
      model.set '_nums.b', 4
      model.set '_nums.c', 7
      result = model.evaluate 'sum', '_nums.a', '_nums.b', '_nums.c'
      expect(result).to.equal 13

    it 'supports scoped model paths', ->
      model = new Model
      model.fn 'sum', (a, b) -> a + b
      $nums = model.at '_nums'
      $nums.set 'a', 2
      $nums.set 'b', 4
      result = model.evaluate 'sum', '_nums.a', '_nums.b'
      expect(result).to.equal 6
      result = $nums.evaluate 'sum', 'a', 'b'
      expect(result).to.equal 6

  describe 'start and stop with getter', ->

    it 'sets the output immediately on start', ->
      model = new Model
      model.fn 'sum', (a, b) -> a + b
      model.set '_nums.a', 2
      model.set '_nums.b', 4
      value = model.start 'sum', '_nums.sum', '_nums.a', '_nums.b'
      expect(value).to.equal 6
      expect(model.get '_nums.sum').to.equal 6

    it 'sets the output when an input changes', ->
      model = new Model
      model.fn 'sum', (a, b) -> a + b
      model.set '_nums.a', 2
      model.set '_nums.b', 4
      model.start 'sum', '_nums.sum', '_nums.a', '_nums.b'
      expect(model.get '_nums.sum').to.equal 6
      model.set '_nums.a', 5
      expect(model.get '_nums.sum').to.equal 9

    it 'sets the output when a parent of the input changes', ->
      model = new Model
      model.fn 'sum', (a, b) -> a + b
      model.set '_nums.in', {a: 2,  b: 4}
      model.start 'sum', '_nums.sum', '_nums.in.a', '_nums.in.b'
      expect(model.get '_nums.sum').to.equal 6
      model.set '_nums.in', {a: 5, b: 7}
      expect(model.get '_nums.sum').to.equal 12

    it 'does not set the output when a sibling of the input changes', ->
      model = new Model
      count = 0
      model.fn 'sum', (a, b) -> count++; a + b
      model.set '_nums.in', {a: 2,  b: 4}
      model.start 'sum', '_nums.sum', '_nums.in.a', '_nums.in.b'
      expect(model.get '_nums.sum').to.equal 6
      expect(count).to.equal 1
      model.set '_nums.in.a', 3
      expect(model.get '_nums.sum').to.equal 7
      expect(count).to.equal 2
      model.set '_nums.in.c', -1
      expect(model.get '_nums.sum').to.equal 7
      expect(count).to.equal 2

    it 'can call stop without start', ->
      model = new Model
      model.stop '_nums.sum'

    it 'stops updating after calling stop', ->
      model = new Model
      model.fn 'sum', (a, b) -> a + b
      model.set '_nums.a', 2
      model.set '_nums.b', 4
      model.start 'sum', '_nums.sum', '_nums.a', '_nums.b'
      model.set '_nums.a', 1
      expect(model.get '_nums.sum').to.equal 5
      model.stop '_nums.sum'
      model.set '_nums.a', 3
      expect(model.get '_nums.sum').to.equal 5

  describe 'setter', ->

    it 'sets the input when the output changes', ->
      model = new Model
      model.fn 'fullName',
        get: (first, last) -> first + ' ' + last
        set: (fullName) -> fullName.split ' '
      model.set '_user.name',
        first: 'John'
        last: 'Smith'
      model.at('_user.name').start 'fullName', 'full', 'first', 'last'
      expect(model.get '_user.name').to.eql
        first: 'John'
        last: 'Smith'
        full: 'John Smith'
      model.set '_user.name.full', 'Jane Doe'
      expect(model.get '_user.name').to.eql
        first: 'Jane'
        last: 'Doe'
        full: 'Jane Doe'

  describe 'event mirroring', ->

    it 'emits move event on output when input changes', (done) ->
      model = new Model
      model.fn 'unity',
        get: (value) -> value
        set: (value) -> [value]
      model.set '_test.in',
        a: [
          {x: 1, y: 2}
          {x: 2, y: 0}
        ]
      model.start 'unity', '_test.out', '_test.in'
      model.on 'all', '_test.out**', (path, event) ->
        expect(event).to.equal 'move'
        expect(path).to.equal 'a'
        done()
      model.move '_test.in.a', 0, 1
      expect(model.get '_test.out').to.eql model.get('_test.in')

    it 'emits move event on input when output changes', (done) ->
      model = new Model
      model.fn 'unity',
        get: (value) -> value
        set: (value) -> [value]
      model.set '_test.in',
        a: [
          {x: 1, y: 2}
          {x: 2, y: 0}
        ]
      model.start 'unity', '_test.out', '_test.in'
      model.on 'all', '_test.in**', (path, event) ->
        expect(event).to.equal 'move'
        expect(path).to.equal 'a'
        done()
      model.move '_test.out.a', 0, 1
      expect(model.get '_test.out').to.eql model.get('_test.in')

    it 'emits granular change event under an array when input changes', (done) ->
      model = new Model
      model.fn 'unity',
        get: (value) -> value
        set: (value) -> [value]
      model.set '_test.in',
        a: [
          {x: 1, y: 2}
          {x: 2, y: 0}
        ]
      model.start 'unity', '_test.out', '_test.in'
      model.on 'all', '_test.out**', (path, event) ->
        expect(event).to.equal 'change'
        expect(path).to.equal 'a.0.x'
        done()
      model.set '_test.in.a.0.x', 3
      expect(model.get '_test.out').to.eql model.get('_test.in')

    it 'emits granular change event under an array when output changes', (done) ->
      model = new Model
      model.fn 'unity',
        get: (value) -> value
        set: (value) -> [value]
      model.set '_test.in',
        a: [
          {x: 1, y: 2}
          {x: 2, y: 0}
        ]
      model.start 'unity', '_test.out', '_test.in'
      model.on 'all', '_test.in**', (path, event) ->
        expect(event).to.equal 'change'
        expect(path).to.equal 'a.0.x'
        done()
      model.set '_test.out.a.0.x', 3
      expect(model.get '_test.out').to.eql model.get('_test.in')
