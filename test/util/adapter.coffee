should = require 'should'
wrapTest = require('../util').wrapTest

module.exports = (Adapter) ->

  'test get and set': wrapTest (done) ->
    adapter = new Adapter
    adapter.get null, (err, value, ver) ->
      should.equal null, err
      value.should.eql {}
      ver.should.eql 0
      
      adapter.set 'color', 'green', 1, (err, value) ->
        should.equal null, err
        value.should.eql 'green'
        adapter.get 'color', (err, value, ver) ->
          should.equal null, err
          value.should.eql 'green'
          ver.should.eql 1
          
          adapter.set 'info.numbers', {first: 2, second: 10}, 2, (err, value) ->
            should.equal null, err
            value.should.eql first: 2, second: 10
            adapter.get 'info.numbers', (err, value, ver) ->
              should.equal null, err
              value.should.eql first: 2, second: 10
              ver.should.eql 2
              adapter.get null, (err, value, ver) ->
                should.equal null, err
                value.should.eql
                  color: 'green'
                  info:
                    numbers:
                      first: 2
                      second: 10
                ver.should.eql 2
                
                adapter.set 'info', 'new', 3, (err, value) ->
                  should.equal null, err
                  adapter.get null, (err, value, ver) ->
                    should.equal null, err
                    value.should.eql color: 'green', info: 'new'
                    ver.should.eql 3
                    done()

  'test del': wrapTest (done) ->
    adapter = new Adapter
    adapter.set 'color', 'green', 1, ->
      adapter.set 'info.numbers', {first: 2, second: 10}, 2, ->
        adapter.del 'color', 3, (err) ->
          should.equal null, err
          adapter.get null, (err, value, ver) ->
            should.equal null, err
            value.should.eql
              info:
                numbers:
                  first: 2
                  second: 10
            ver.should.eql 3
            
            adapter.del 'info.numbers', 4, (err) ->
              should.equal null, err
              adapter.get null, (err, value, ver) ->
                should.equal null, err
                value.should.eql info: {}
                ver.should.eql 4
                done()

  'test flush': wrapTest (done) ->
    adapter = new Adapter
    adapter.set 'color', 'green', 1, ->
      adapter.flush (err) ->
        should.equal null, err
        adapter.get null, (err, value, ver) ->
          should.equal null, err
          value.should.eql {}
          ver.should.eql 0
          done()
