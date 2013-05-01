{expect} = require '../util'
Model = require '../../lib/Model'

describe 'ref', ->

  setup = ->
      model = (new Model).at '_page'
      model.set 'colors',
        green:
          id: 'green'
          rgb: [0, 255, 0]
          hex: '#0f0'
        red:
          id: 'red'
          rgb: [255, 0, 0]
          hex: '#f00'
      model.set 'ids', ['red', 'green', 'red']
      model.refList 'list', 'colors', 'ids'
      return model

  expectEvents = (model, done, events) ->
    model.on 'all', 'list**', ->
      events.shift() arguments...
      done() unless events.length

  describe 'sets output on initial call', ->

    it 'sets the initial value to empty array if no inputs', ->
      model = (new Model).at '_page'
      model.refList 'empty', 'colors', 'noIds'
      expect(model.get 'empty').to.eql []

    it 'sets the initial value for already populated data', ->
      model = setup()
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]

  describe 'updates on `ids` mutations', ->

    it 'updates the value when `ids` is set', ->
      model = (new Model).at '_page'
      model.set 'colors',
        green:
          id: 'green'
          rgb: [0, 255, 0]
          hex: '#0f0'
        red:
          id: 'red'
          rgb: [255, 0, 0]
          hex: '#f00'
      model.refList 'list', 'colors', 'ids'
      expect(model.get 'list').to.eql []
      model.set 'ids', ['red', 'green', 'red']
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]

    it 'emits on `from` when `ids` is set', (done) ->
      model = (new Model).at '_page'
      model.set 'colors',
        green:
          id: 'green'
          rgb: [0, 255, 0]
          hex: '#0f0'
        red:
          id: 'red'
          rgb: [255, 0, 0]
          hex: '#f00'
      model.refList 'list', 'colors', 'ids'
      model.on 'all', 'list**', (capture, method, index, values) ->
        expect(capture).to.equal ''
        expect(method).to.equal 'insert'
        expect(index).to.equal 0
        expect(values).to.eql [
          {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
          {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
          {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        ]
        done()
      model.set 'ids', ['red', 'green', 'red']

    it 'updates the value when `ids` children are set', ->
      model = setup()
      model.set 'ids.0', 'green'
      expect(model.get 'list').to.eql [
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]
      model.set 'ids.2', 'blue'
      expect(model.get 'list').to.eql [
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        undefined
      ]

    it 'emits on `from` when `ids` children are set', (done) ->
      model = setup()
      model.on 'all', 'list**', (capture, method, value, previous) ->
        expect(capture).to.equal '2'
        expect(method).to.equal 'change'
        expect(value).to.eql {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        expect(previous).to.eql {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        done()
      model.set 'ids.2', 'green'

    it 'updates the value when `ids` are inserted', ->
      model = setup()
      model.push 'ids', 'green'
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
      ]
      model.insert 'ids', 1, ['blue', 'red']
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        undefined
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
      ]

    it 'emits on `from` when `ids` are inserted', (done) ->
      model = setup()   
      model.on 'all', 'list**', (capture, method, index, inserted) ->
        expect(capture).to.equal ''
        expect(method).to.equal 'insert'
        expect(index).to.equal 1
        expect(inserted).to.eql [
          undefined
          {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        ]
        done()
      model.insert 'ids', 1, ['blue', 'red']

    it 'updates the value when `ids` are removed', ->
      model = setup()
      model.pop 'ids'
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
      ]
      model.remove 'ids', 0, 2
      expect(model.get 'list').to.eql []

    it 'emits on `from` when `ids` are removed', (done) ->
      model = setup()
      model.on 'all', 'list**', (capture, method, index, removed) ->
        expect(capture).to.equal ''
        expect(method).to.equal 'remove'
        expect(index).to.equal 0
        expect(removed).to.eql [
          {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
          {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        ]
        done()
      model.remove 'ids', 0, 2

    it 'updates the value when `ids` are moved', ->
      model = setup()
      model.move 'ids', 0, 2, 2
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
      ]
      model.move 'ids', 2, 0
      expect(model.get 'list').to.eql [
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]

    it 'emits on `from` when `ids` are moved', (done) ->
      model = setup()
      model.on 'all', 'list**', (capture, method, from, to, howMany) ->
        expect(capture).to.equal ''
        expect(method).to.equal 'move'
        expect(from).to.equal 0
        expect(to).to.equal 2
        expect(howMany).to.eql 2
        done()
      model.move 'ids', 0, 2, 2

  describe 'updates on `to` mutations', ->

    it 'updates the value when `to` is set', ->
      model = (new Model).at '_page'
      model.set 'ids', ['red', 'green', 'red']
      model.refList 'list', 'colors', 'ids'
      expect(model.get 'list').to.eql [undefined, undefined, undefined]
      model.set 'colors',
        green:
          id: 'green'
          rgb: [0, 255, 0]
          hex: '#0f0'
        red:
          id: 'red'
          rgb: [255, 0, 0]
          hex: '#f00'
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]

    it 'emits on `from` when `to` is set', (done) ->
      model = (new Model).at '_page'
      model.set 'ids', ['red', 'green', 'red']
      model.refList 'list', 'colors', 'ids'
      expectEvents model, done, [
        (capture, method, index, removed) ->
          expect(capture).to.equal ''
          expect(method).to.equal 'remove'
          expect(index).to.equal 0
          expect(removed).to.eql [undefined, undefined, undefined]
      , (capture, method, index, inserted) ->
          expect(capture).to.equal ''
          expect(method).to.equal 'insert'
          expect(index).to.equal 0
          expect(inserted).to.eql [
            {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
            {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
            {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
          ]
      ]
      model.set 'colors',
        green:
          id: 'green'
          rgb: [0, 255, 0]
          hex: '#0f0'
        red:
          id: 'red'
          rgb: [255, 0, 0]
          hex: '#f00'

    it 'updates the value when `to` children are set', ->
      model = (new Model).at '_page'
      model.set 'ids', ['red', 'green', 'red']
      model.refList 'list', 'colors', 'ids'
      model.set 'colors.green',
        id: 'green'
        rgb: [0, 255, 0]
        hex: '#0f0'
      expect(model.get 'list').to.eql [
        undefined
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        undefined
      ]
      model.set 'colors.red',
        id: 'red'
        rgb: [255, 0, 0]
        hex: '#f00'
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]
      model.del 'colors.green'
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        undefined
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]

    it 'emits on `from` when `to` children are set', (done) ->
      model = (new Model).at '_page'
      model.set 'ids', ['red', 'green', 'red']
      model.refList 'list', 'colors', 'ids'
      expectEvents model, done, [
        (capture, method, value, previous) ->
          expect(capture).to.equal '0'
          expect(method).to.equal 'change'
          expect(value).to.eql {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
          expect(previous).to.equal undefined
      , (capture, method, value, previous) ->
          expect(capture).to.equal '2'
          expect(method).to.equal 'change'
          expect(value).to.eql {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
          expect(previous).to.equal undefined
      ]
      model.set 'colors.red',
        id: 'red'
        rgb: [255, 0, 0]
        hex: '#f00'

    it 'updates the value when `to` descendants are set', ->
      model = setup()
      model.set 'colors.red.hex', '#e00'
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#e00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#e00'}
      ]
      model.set 'colors.red.rgb.0', 238
      expect(model.get 'list').to.eql [
        {id: 'red', rgb: [238, 0, 0], hex: '#e00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [238, 0, 0], hex: '#e00'}
      ]

    it 'emits on `from` when `to` descendants are set', (done) ->
      model = setup()
      expectEvents model, done, [
        (capture, method, value, previous) ->
          expect(capture).to.equal '0.hex'
          expect(method).to.equal 'change'
          expect(value).to.eql '#e00'
          expect(previous).to.equal '#f00'
      , (capture, method, value, previous) ->
          expect(capture).to.equal '2.hex'
          expect(method).to.equal 'change'
          expect(value).to.eql '#e00'
          expect(previous).to.equal '#f00'
      , (capture, method, value, previous) ->
          expect(capture).to.equal '0.rgb.0'
          expect(method).to.equal 'change'
          expect(value).to.eql 238
          expect(previous).to.equal 255
      , (capture, method, value, previous) ->
          expect(capture).to.equal '2.rgb.0'
          expect(method).to.equal 'change'
          expect(value).to.eql 238
          expect(previous).to.equal 255
      ]
      model.set 'colors.red.hex', '#e00'
      model.set 'colors.red.rgb.0', 238

    it 'updates the value when inserting on `to` children', ->
      model = (new Model).at '_page'
      model.set 'nums',
        even: [2, 4, 6]
        odd: [1, 3]
      model.set 'ids', ['even', 'odd', 'even']
      model.refList 'list', 'nums', 'ids'
      expect(model.get 'list').to.eql [
        [2, 4, 6]
        [1, 3]
        [2, 4, 6]
      ]
      model.push 'nums.even', 8
      expect(model.get 'list').to.eql [
        [2, 4, 6, 8]
        [1, 3]
        [2, 4, 6, 8]
      ]

    it 'emits on `from` when inserting on `to` children', (done) ->
      model = (new Model).at '_page'
      model.set 'nums',
        even: [2, 4, 6]
        odd: [1, 3]
      model.set 'ids', ['even', 'odd', 'even']
      model.refList 'list', 'nums', 'ids'
      expectEvents model, done, [
        (capture, method, index, inserted) ->
          expect(capture).to.equal '0'
          expect(method).to.equal 'insert'
          expect(index).to.equal 3
          expect(inserted).to.eql [8]
      , (capture, method, index, inserted) ->
          expect(capture).to.equal '2'
          expect(method).to.equal 'insert'
          expect(index).to.equal 3
          expect(inserted).to.eql [8]
      ]
      model.push 'nums.even', 8

  describe 'updates on `from` mutations', ->

    it 'updates `to` and `ids` when `from` is set', ->
      model = setup()
      model.set 'list', [
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]
      expect(model.get 'ids').to.eql ['green', 'red']
      expect(model.get 'colors').to.eql
        green: {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        red: {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      # Changing items in the `from` list can only create new objects
      # under `to`, and it does not remove them
      model.del 'list'
      expect(model.get 'ids').to.eql []
      expect(model.get 'colors').to.eql
        green: {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        red: {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      model.set 'list', [
        {id: 'blue', rgb: [0, 0, 255], hex: '#00f'}
        {id: 'yellow', rgb: [255, 255, 0], hex: '#ff0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]
      expect(model.get 'ids').to.eql ['blue', 'yellow', 'red']
      expect(model.get 'colors').to.eql
        green: {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        red: {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        blue: {id: 'blue', rgb: [0, 0, 255], hex: '#00f'}
        yellow: {id: 'yellow', rgb: [255, 255, 0], hex: '#ff0'}
