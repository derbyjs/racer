should = require 'should'
Store = require 'Store'
MongoAdapter = require 'adapters/Mongo'
adapter = new MongoAdapter
adapter.connect('mongodb://localhost/rally_test')

module.exports =
  setup: (done) ->
    adapter.flush done

  teardown: (done) ->
    adapter.flush done

  'should be able to get a path that is set': (done) ->
    adapter.set 'users.0.username', 'brian', ver=1, null, (err) ->
      should.equal null, err
      adapter.get 'users.0.username', null, (err, val, ver) ->
        should.equal null, err
        val.should.equal 'brian'
        ver.should.equal 1
        done()

  'should be able to set an entire doc, and then get all or parts it': (done) ->
    adapter.set 'users.1', { name: { first: 'brian', last: 'noguchi' } }, ver=1, null, (err) ->
      should.equal null, err
      adapter.get 'users.1.name', null, (err, val, ver) ->
        should.equal null, err
        val.should.eql { first: 'brian', last: 'noguchi' }
        ver.should.equal 1
        done()

  'should be able to set a path to an object, and then get all or parts of it': (done) ->
    adapter.set 'users.1.bio', { name: { first: 'brian', last: 'noguchi' } }, ver=1, null, (err) ->
      should.equal null, err
      adapter.get 'users.1.bio', null, (err, val, ver) ->
        should.equal null, err
        val.should.eql { name: { first: 'brian', last: 'noguchi' } }
        ver.should.equal 1
        done()

  # TODO Test updating a parent node in a path chain. Make sure it over-rides the
  #      prior descendants that are not mentioned in the new path chain

  'should resolve a non-existent document as undefined': (done) ->
    adapter.get 'users.2', null, (err, val, ver) ->
      should.equal null, err
      should.equal undefined, val
      should.equal undefined, ver
      done()

  'should resolve a non-existent path on a non-existing document as undefined': (done) ->
    adapter.get 'users.2.username', null, (err, val, ver) ->
      should.equal null, err
      should.equal undefined, val
      should.equal undefined, ver
      done()

  'should resolve a non-existent path on an existing document as undefined': (done) ->
    adapter.set 'users.2.username', 'brian', ver=1, null, (err) ->
      should.equal null, err
      adapter.get 'users.2.realname', null, (err, val, ver) ->
        should.equal null, err
        should.equal undefined, val
        should.equal 1, ver
        done()

  'should remove a path, not the document on del': (done) ->
    adapter.set 'users.3.username', 'brian', ver=1, null, (err) ->
      should.equal null, err
      adapter.set 'users.3.realname', 'Brian', ver=2, null, (err) ->
        should.equal null, err
        adapter.del 'users.3.username', ver, null, (err) ->
          should.equal null, err
          adapter.get 'users.3.username', null, (err, val, ver) ->
            should.equal null, err
            should.equal undefined, val
            should.equal ver, 2
            adapter.get 'users.3', null, (err, val, ver) ->
              should.equal null, err
              val.should.eql {_id: 3, realname: 'Brian'}
              should.equal ver, 2
              done()

  'should be able to remove a document with del': (done) ->
    adapter.set 'users.4.username', 'brian', ver=1, null, (err) ->
      should.equal null, err
      adapter.del 'users.4', 1, null, (err) ->
        should.equal null, err
        adapter.get 'users.4', null, (err, val, ver) ->
          should.equal null, err
          should.equal undefined, val
          should.equal undefined, ver
          done()

  finishAll: (done) ->
    adapter.disconnect()
    done()
