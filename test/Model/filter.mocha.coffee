{expect} = require '../util'
Model = require '../../lib/Model'

describe 'filter', ->

  describe 'getting', ->

    it 'supports filter of array', ->
      model = (new Model).at '_page'
      model.set 'numbers', [0, 3, 4, 1, 2, 3, 0]
      filter = model.filter 'numbers', (number, i, numbers) ->
        return (number % 2) == 0
      expect(filter.get()).to.eql [0, 4, 2, 0]

    it 'supports sort of array', ->
      model = (new Model).at '_page'
      model.set 'numbers', [0, 3, 4, 1, 2, 3, 0]
      filter = model.sort 'numbers'
      expect(filter.get()).to.eql [0, 0, 1, 2, 3, 3, 4]
      filter = model.sort 'numbers', 'asc'
      expect(filter.get()).to.eql [0, 0, 1, 2, 3, 3, 4]
      filter = model.sort 'numbers', 'desc'
      expect(filter.get()).to.eql [4, 3, 3, 2, 1, 0, 0]

    it 'supports filter and sort of array', ->
      model = (new Model).at '_page'
      model.set 'numbers', [0, 3, 4, 1, 2, 3, 0]
      model.fn 'even', (number) ->
        return (number % 2) == 0
      filter = model.filter('numbers', 'even').sort()
      expect(filter.get()).to.eql [0, 0, 2, 4]

    it 'supports filter of object', ->
      model = (new Model).at '_page'
      for number in [0, 3, 4, 1, 2, 3, 0]
        model.set 'numbers.' + model.id(), number
      filter = model.filter 'numbers', (number, id, numbers) ->
        return (number % 2) == 0
      expect(filter.get()).to.eql [0, 4, 2, 0]

    it 'supports sort of object', ->
      model = (new Model).at '_page'
      for number in [0, 3, 4, 1, 2, 3, 0]
        model.set 'numbers.' + model.id(), number
      filter = model.sort 'numbers'
      expect(filter.get()).to.eql [0, 0, 1, 2, 3, 3, 4]
      filter = model.sort 'numbers', 'asc'
      expect(filter.get()).to.eql [0, 0, 1, 2, 3, 3, 4]
      filter = model.sort 'numbers', 'desc'
      expect(filter.get()).to.eql [4, 3, 3, 2, 1, 0, 0]

    it 'supports filter and sort of object', ->
      model = (new Model).at '_page'
      for number in [0, 3, 4, 1, 2, 3, 0]
        model.set 'numbers.' + model.id(), number
      model.fn 'even', (number) ->
        return (number % 2) == 0
      filter = model.filter('numbers', 'even').sort()
      expect(filter.get()).to.eql [0, 0, 2, 4]

  describe 'initial value set by ref', ->

    it 'supports filter of array', ->
      model = (new Model).at '_page'
      model.set 'numbers', [0, 3, 4, 1, 2, 3, 0]
      filter = model.filter 'numbers', (number) ->
        return (number % 2) == 0
      filter.ref '_page.out'
      expect(model.get 'out').to.eql [0, 4, 2, 0]

    it 'supports sort of array', ->
      model = (new Model).at '_page'
      model.set 'numbers', [0, 3, 4, 1, 2, 3, 0]
      filter = model.sort 'numbers'
      expect(filter.get()).to.eql [0, 0, 1, 2, 3, 3, 4]
      filter = model.sort 'numbers', 'asc'
      expect(filter.get()).to.eql [0, 0, 1, 2, 3, 3, 4]
      filter = model.sort 'numbers', 'desc'
      filter.ref '_page.out'
      expect(model.get 'out').to.eql [4, 3, 3, 2, 1, 0, 0]

    it 'supports filter and sort of array', ->
      model = (new Model).at '_page'
      model.set 'numbers', [0, 3, 4, 1, 2, 3, 0]
      model.fn 'even', (number) ->
        return (number % 2) == 0
      filter = model.filter('numbers', 'even').sort()
      filter.ref '_page.out'
      expect(model.get 'out').to.eql [0, 0, 2, 4]

    it 'supports filter of object', ->
      model = (new Model).at '_page'
      for number in [0, 3, 4, 1, 2, 3, 0]
        model.set 'numbers.' + model.id(), number
      filter = model.filter 'numbers', (number) ->
        return (number % 2) == 0
      filter.ref '_page.out'
      expect(model.get 'out').to.eql [0, 4, 2, 0]

    it 'supports sort of object', ->
      model = (new Model).at '_page'
      for number in [0, 3, 4, 1, 2, 3, 0]
        model.set 'numbers.' + model.id(), number
      filter = model.sort 'numbers'
      expect(filter.get()).to.eql [0, 0, 1, 2, 3, 3, 4]
      filter = model.sort 'numbers', 'asc'
      expect(filter.get()).to.eql [0, 0, 1, 2, 3, 3, 4]
      filter = model.sort 'numbers', 'desc'
      filter.ref '_page.out'
      expect(model.get 'out').to.eql [4, 3, 3, 2, 1, 0, 0]

    it 'supports filter and sort of object', ->
      model = (new Model).at '_page'
      for number in [0, 3, 4, 1, 2, 3, 0]
        model.set 'numbers.' + model.id(), number
      model.fn 'even', (number) ->
        return (number % 2) == 0
      filter = model.filter('numbers', 'even').sort()
      filter.ref '_page.out'
      expect(model.get 'out').to.eql [0, 0, 2, 4]

  describe 'ref updates as items are modified', ->

    it 'supports filter of array', ->
      model = (new Model).at '_page'
      model.set 'numbers', [0, 3, 4, 1, 2, 3, 0]
      filter = model.filter 'numbers', (number) ->
        return (number % 2) == 0
      filter.ref '_page.out'
      expect(model.get 'out').to.eql [0, 4, 2, 0]
      model.push 'numbers', 6
      expect(model.get 'out').to.eql [0, 4, 2, 0, 6]
      model.set 'numbers.2', 1
      expect(model.get 'out').to.eql [0, 2, 0, 6]
      model.del 'numbers'
      expect(model.get 'out').to.eql []
      model.set 'numbers', [1, 2, 0]
      expect(model.get 'out').to.eql [2, 0]

    it 'supports filter of object', ->
      model = (new Model).at '_page'
      greenId = model.add 'colors'
        name: 'green'
        primary: true
      orangeId = model.add 'colors'
        name: 'orange'
        primary: false
      redId = model.add 'colors'
        name: 'red'
        primary: true
      filter = model.filter 'colors', (color) -> color.primary
      filter.ref '_page.out'
      expect(model.get 'out').to.eql [
        {name: 'green', primary: true, id: greenId}
        {name: 'red', primary: true, id: redId}
      ]
      model.set 'colors.' + greenId + '.primary', false
      expect(model.get 'out').to.eql [
        {name: 'red', primary: true, id: redId}
      ]
      yellowId = model.add 'colors'
        name: 'yellow'
        primary: true
      expect(model.get 'out').to.eql [
        {name: 'red', primary: true, id: redId}
        {name: 'yellow', primary: true, id: yellowId}
      ]
