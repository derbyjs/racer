transaction = require '../transaction'
pathParser = require '../pathParser'
{all: mutators} = require '../mutators'
RefHelper = require './RefHelper'

module.exports =

  init: ->
    @_refHelper = new RefHelper this

  proto:
    ref: (ref, key) ->
      if key? then $r: ref, $k: key else $r: ref

    arrayRef: (ref, key) ->
      $r: ref, $k: key, $t: 'array'

    # This overrides a method created by mixin.stm
    # TODO: This is super messy right now. Clean this up!
    _addOpAsTxn: (method, path, args..., callback) ->
      # TODO: There is a lot of mutation of txn going on here. Clean this up.
      refHelper = @_refHelper
      self = this

      # In case we did atomicModel.get()
      unless nullPath = path is null
        # Transform args if path represents an array ref
        # argsNormalizer = new ArgsNormalizer refHelper
        # args = argsNormalizer.transform(method, path, args)
        if {$r, $k} = refHelper.isArrayRef path, @_specModel()
          [firstArgs, members] = mutators[method].splitArgs args
          members = members.map (member) ->
            return member if refHelper.isRef member
            # MUTATION
            self.set $r + '.' + member.id, member
            return {$r, $k: member.id.toString()}
          args = firstArgs.concat members

        # Convert id args to index args if we happen to be
        # using array ref mutator id api
        if mutators[method]?.indexArgs
          idAsIndex = refHelper.arrRefIndex args[0], path, @_specModel()
      
      # Create a new transaction and add it to a local queue
      ver = @_getVer()
      id = @_nextTxnId()
      txn = transaction.create base: ver, id: id, method: method, args: [path, args...]
      # NOTE: This converts the transaction
      unless nullPath
        txn = refHelper.dereferenceTxn txn, @_specModel()

      @_queueTxn txn, callback

      unless nullPath
        txnArgs = transaction.args txn
        path = txnArgs[0]
        # Apply a private transaction immediately and don't send it to the store
        if pathParser.isPrivate path
          @_cache.invalidateSpecModelCache()
          return @_applyTxn txn, !txn.emitted && !@_silent

        if idAsIndex isnt undefined
          meta = txnArgs[1] # txnArgs[1] has form {id: id}
          meta.index = idAsIndex
          transaction.meta txn, meta

        # Emit an event on creation of the transaction
        unless @_silent
          @emit method, txnArgs, true
          txn.emitted = true

        txnArgs[1] = idAsIndex if idAsIndex isnt undefined

      # Send it over Socket.IO or to the store on the server
      @_commit txn
  
  RefHelper: RefHelper
