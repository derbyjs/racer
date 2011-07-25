should = require 'should'
pathParser = require 'pathParser'
require 'pathParser.server'

module.exports =
  'paths containing a segment starting with an underscore should be private': ->
    pathParser.isPrivate('_stuff').should.be.true
    pathParser.isPrivate('item._stu_ff').should.be.true
    pathParser.isPrivate('a.b.c.d._e.f.g').should.be.true
    pathParser.isPrivate('a').should.be.false
    pathParser.isPrivate('item.stuff').should.be.false
    pathParser.isPrivate('item_.stuff').should.be.false
    pathParser.isPrivate('item.stuff_').should.be.false
    pathParser.isPrivate('item_sdf.s_tuff').should.be.false
