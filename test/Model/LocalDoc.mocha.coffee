{expect} = require '../util'
LocalDoc = require '../../lib/Model/LocalDoc'
docs = require './docs'

describe 'LocalDoc', ->

  createDoc = -> new LocalDoc '_colors', 'green'

  docs createDoc
