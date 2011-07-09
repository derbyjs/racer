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
  json: ->
    data: @_data
    base: @_base
    clientId: @_clientId
    txnCount: @_txnCount
  js: ->
    """
    (function() {
      var model = rally.model;
      model._data = #{JSON.stringify @_data};
      model._base = #{JSON.stringify @_base};
      model._clientId = #{JSON.stringify @_clientId};
      model._txnCount = #{JSON.stringify @_txnCount};
    })();
    """