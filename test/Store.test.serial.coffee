should = require 'should'
Store = require 'server/Store'
MemoryAdapter = require 'server/adapters/Memory'
store = new Store(MemoryAdapter)

# TODO Stub Stm

module.exports =
  setup: (done) ->
    store.flush done

  teardown: (done) ->
    store.flush done

#  'set should store a non-special key directly': (done) ->
#    store.set 'a.b.c', 'hello', 5, (err) ->
#      should.equal null, err
#      store.adapter._data['a.b.c'].should.equal 'hello'
#      done()
#
  'can create a doc object for a doc.path key': (done) ->
    store.set 'pets.1.name.first', 'banana', 6, (err) ->
      should.equal null, err
      store.adapter._data['pets.1'].should.eql
        ver: 6
        name:
          first: 'banana'
      done()

  '#set throws an error if you forget the version': (done) ->
    err = false
    try
      store.set 'pets.1.name.first', 'banana', ->
    catch e
      err = true
    err.should.be.true
    done()

  'can retrieve a path': (done) ->
    store.set 'pets.1.name.first', 'squeak', 5
    store.set 'pets.1.name.first', 'banana', 6
    store.get 'pets.1.name.first', (err, val, ver, doc) ->
      should.equal null, err
      val.should.equal 'banana'
      ver.should.equal 6
      doc.should.eql
        ver: 6
        name:
          first: 'banana'
      done()

  'should be able to retrieve a multiple paths at once': (done) ->
    store.set 'a.b.c', 'hello', 5
    store.set 'pets.1.name.first', 'banana', 6
    store.mget 'pets.1.name.first', 'a.b.c', (err, data, maxVer) ->
      should.equal null, err
      data.should.eql ['banana', 'hello']
      maxVer.should.equal 6
      done()



#  # Versioning
#
#  'should store a version with every created object': (done) ->
#    store.set 1, { a: 'a' }, (err, doc) ->
#      store.get 1, (err, doc) ->
#        doc.should.have.property 'ver'
#        done()
#
#  "should update an object's version when it updates the object": (done) ->
#    store.set 2, { b: 'b' }, (err, doc) ->
#      store.get 2, (err, doc) ->
#        ver0 = doc.ver
#        store.set 2, { a: 'a', b: 'b' }, (err, doc) ->
#          store.get 2, (err, doc) ->
#            verF = doc.ver
#            verF.should.be.above ver0
