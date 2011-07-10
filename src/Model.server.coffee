module.exports =
  _setStm: (stm) ->
    onTxn = @_onTxn
    @_send = (txn) ->
      stm.commit txn, (err, ver) ->
        # TODO: Handle STM conflicts and other errors
        if ver
          txn[0] = ver
          onTxn txn
        return true
  json: -> JSON.stringify
    data: @_data
    base: @_base
    clientId: @_clientId
    txnCount: @_txnCount
    ioUri: @_ioUri
