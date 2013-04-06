{expect} = require '../util'
RemoteDoc = require '../../lib/Model/RemoteDoc'
docs = require './docs'

describe 'RemoteDoc', ->

  createDoc = -> new RemoteDoc '_colors', 'green'

  # docs createDoc
