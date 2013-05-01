{expect} = require '../util'
Model = require '../../lib/Model'

describe 'ref', ->

  describe 'updates for getting', ->

    it 'sets the initial value to empty array if no inputs', ->
      model = (new Model).at '_page'
      model.refList 'empty', 'colors', 'noIds'

    it 'sets the initial value for already populated data', ->
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
      model.set 'colorIds', ['red', 'green', 'red']
      model.refList 'colorList', 'colors', 'colorIds'
      expect(model.get 'colorList').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]

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
      model.refList 'colorList', 'colors', 'colorIds'
      expect(model.get 'colorList').to.eql []
      model.set 'colorIds', ['red', 'green', 'red']
      expect(model.get 'colorList').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]

    it 'updates the value when `ids` children are set', ->
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
      model.set 'colorIds', ['red', 'green', 'red']
      model.refList 'colorList', 'colors', 'colorIds'
      model.set 'colorIds.0', 'green'
      expect(model.get 'colorList').to.eql [
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]
      model.set 'colorIds.2', 'blue'
      expect(model.get 'colorList').to.eql [
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        undefined
      ]

    it 'updates the value when `ids` are inserted', ->
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
      model.set 'colorIds', ['red', 'green', 'red']
      model.refList 'colorList', 'colors', 'colorIds'
      model.push 'colorIds', 'green'
      expect(model.get 'colorList').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
      ]
      model.insert 'colorIds', 1, ['blue', 'red']
      expect(model.get 'colorList').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        undefined
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
      ]

    it 'updates the value when `to` is set', ->
      model = (new Model).at '_page'
      model.set 'colorIds', ['red', 'green', 'red']
      model.refList 'colorList', 'colors', 'colorIds'
      expect(model.get 'colorList').to.eql []
      model.set 'colors',
        green:
          id: 'green'
          rgb: [0, 255, 0]
          hex: '#0f0'
        red:
          id: 'red'
          rgb: [255, 0, 0]
          hex: '#f00'
      expect(model.get 'colorList').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]

    it 'updates the value when `to` children are set', ->
      model = (new Model).at '_page'
      model.set 'colorIds', ['red', 'green', 'red']
      model.refList 'colorList', 'colors', 'colorIds'
      model.set 'colors.green',
        id: 'green'
        rgb: [0, 255, 0]
        hex: '#0f0'
      expect(model.get 'colorList').to.eql [
        undefined
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        undefined
      ]
      model.set 'colors.red',
        id: 'red'
        rgb: [255, 0, 0]
        hex: '#f00'
      expect(model.get 'colorList').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]
      model.del 'colors.green'
      expect(model.get 'colorList').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        undefined
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]

    it 'updates the value when `to` descendants are set', ->
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
      model.set 'colorIds', ['red', 'green', 'red']
      model.refList 'colorList', 'colors', 'colorIds'
      model.set 'colors.red.hex', '#e00'
      expect(model.get 'colorList').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#e00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#e00'}
      ]
      model.set 'colors.red.rgb.0', 238
      expect(model.get 'colorList').to.eql [
        {id: 'red', rgb: [238, 0, 0], hex: '#e00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [238, 0, 0], hex: '#e00'}
      ]
