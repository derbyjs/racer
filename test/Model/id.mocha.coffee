{expect} = require '../util'
{BrowserModel: Model} = require '../util/model'

describe 'Model.id', ->

  it 'supports an id method for creating a guid', ->
    model = new Model
    model._clientId = '0'
    id00 = model.id()
    id01 = model.id()

    model = new Model
    model._clientId = '1'
    id10 = model.id()

    expect(id00).to.be.a 'string'
    expect(id01).to.be.a 'string'
    expect(id10).to.be.a 'string'

    expect(id00).to.not.eql id01
    expect(id00).to.not.eql id10
