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
    adapter.set 'users.0.username', 'brian', ver=1, (err) ->
      should.equal null, err
      adapter.get 'users.1.username', (err, val, ver) ->
        should.equal null, err
        val.should.equal 'brian'
        ver.should.equal 1
        done()

  'should be able to set an entire doc, and then get all or parts it': (done) ->
    adapter.set 'users.1', { name: { first: 'brian', last: 'noguchi' } }, ver=1, (err) ->
      should.equal null, err
      adapter.get 'users.1.name', (err, val, ver) ->
        should.equal null, err
        val.should.eql { first: 'brian', last: 'noguchi' }
        ver.should.equal 1
        done()

  'should resolve a non-existent document as undefined': (done) ->
    adapter.get 'users.2', (err, val, ver) ->
      should.equal null, err
      should.equal undefined, val
      should.equal undefined, ver
      done()

  'should resolve a non-existent path on a non-existing document as undefined': (done) ->
    adapter.get 'users.2.username', (err, val, ver) ->
      should.equal null, err
      should.equal undefined, val
      should.equal undefined, ver
      done()

  'should resolve a non-existent path on an existing document as undefined': (done) ->
    adapter.set 'users.2.username', 'brian', ver=1, (err) ->
      should.equal null, err
      adapter.get 'users.2.realname', (err, val, ver) ->
        should.equal null, err
        should.equal undefined, val
        should.equal 1, ver
        done()

  'should remove a path, not the document on del': (done) ->
    adapter.set 'users.3.username', 'brian', ver=1, (err) ->
      should.equal null, err
      adapter.set 'users.3.realname', 'Brian', ver=2, (err) ->
        should.equal null, err
        adapter.del 'users.3.username', ver, (err) ->
          should.equal null, err
          adapter.get 'users.3.username', (err, val, ver) ->
            should.equal null, err
            should.equal undefined, val
            should.equal ver, 2
            adapter.get 'users.3', (err, val, ver) ->
              should.equal null, err
              val.should.eql {_id: 3, realname: 'Brian'}
              should.equal ver, 2
              done()

  'should be able to remove a document with del': (done) ->
    adapter.set 'users.4.username', 'brian', ver=1, (err) ->
      should.equal null, err
      adapter.del 'users.4', 1, (err) ->
        should.equal null, err
        adapter.get 'users.4', (err, val, ver) ->
          should.equal null, err
          should.equal undefined, val
          should.equal undefined, ver
          done()

  finishAll: (done) ->
    adapter.disconnect()
    done()
