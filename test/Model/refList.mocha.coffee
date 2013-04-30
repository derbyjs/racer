{expect} = require '../util'
Model = require '../../lib/Model'

describe 'ref', ->

  describe 'updates for getting', ->

    it 'sets the initial value to empty array if no inputs', ->
      model = new Model
      model.refList '_page.empty', '_colors', '_page.noIds'
      expect(model.get '_page.empty').to.eql []

    it 'sets the initial value for already populated data', ->
      model = new Model
      model.setEach '_colors',
        green:
          id: 'green'
          rgb: [0, 255, 0]
          hex: '#0f0'
        red:
          id: 'red'
          rgb: [255, 0, 0]
          hex: '#f00'
      model.set '_page.colorIds', ['red', 'green', 'red']
      model.refList '_page.colors', '_colors', '_page.colorIds'
      expect(model.get '_page.colors').to.eql [
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
        {id: 'green', rgb: [0, 255, 0], hex: '#0f0'}
        {id: 'red', rgb: [255, 0, 0], hex: '#f00'}
      ]
