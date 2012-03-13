{diffArrays} = require '../diffMatchPatch'
{eventRegExp, lookup} = require '../path'
{deepCopy} = require '../util'
transaction = require '../transaction'

module.exports =
  txnEffect: txnEffect = (txn, method, args) ->
    switch method
      when 'push'
        ins = transaction.getMeta txn
        num = args.length - 1
      when 'unshift'
        ins = 0
        num = args.length - 1
      when 'insert'
        ins = args[1]
        num = args.length - 2
      when 'pop'
        rem = transaction.getMeta txn
        num = 1
      when 'shift'
        rem = 0
        num = 1
      when 'remove'
        rem = args[1]
        num = args[2]
      when 'move'
        ins = args[1]
        rem = args[2]
        num = 1
    return [ins, rem, num]

  # Given a txn, does a diff based on the txnQueue
  mergeTxn: (txn, txns, txnQueue, arrayMutator, memory, before, after) ->
    path = transaction.getPath txn
    method = transaction.getMethod txn
    args = transaction.getArgs txn
    if isArrayMutator = arrayMutator[method]
      [ins, rem, num] = txnEffect txn, method, args
      arraySubPath = eventRegExp "(#{path}.(\\d+)).*"
    beforeData = before._data
    afterData = after._data
    resetPaths = []
    patchConcat = []
    for id in txnQueue
      txnQ = txns[id]
      continue if txnQ.callback
      pathQ = transaction.getPath txnQ
      continue unless transaction.pathConflict path, pathQ
      methodQ = transaction.getMethod txnQ
      if isArrayMutator || arrayMutator[methodQ]
        unless arrPath
          if isArrayMutator
            arrPath = path
          else
            # If an incoming txn modifies an existing object child
            # of the array, the diff won't detect the operation's
            # effect, and the txn should be emitted normally
            arraySubPath = eventRegExp "(#{pathQ}.\\d+).*"
            continue if (match = arraySubPath.exec path) &&
              (typeof memory.get(match[1]) is 'object')
            arrPath = pathQ
          arr = memory.get(arrPath)
          before.set arrPath, arr && arr.slice(), 1, beforeData
          after.set arrPath, arr && arr.slice(), 1, afterData
          after[method] args.concat(1, afterData)...
        argsQ = deepCopy transaction.getArgs(txnQ)
        if arraySubPath && (match = arraySubPath.exec pathQ)
          parentPath = match[1]
          i = +match[2]
          i += num  if i >= ins
          i -= num  if i >= rem
          if typeof before.get(parentPath) is 'object'
            resetPaths.push ["#{path}.#{i}", match[3]]
            patchConcat.push method: methodQ, args: argsQ
            continue
        before[methodQ] argsQ.concat(1, beforeData)...
        after[methodQ] argsQ.concat(1, afterData)...
      else
        # If there is a conflict, re-emit when applying
        txnQ.emitted = false

    if arrPath
      txn.patch = patch = []
      diff = diffArrays before.get(arrPath), after.get(arrPath)
      for op in diff
        method = op[0]
        op[0] = arrPath
        patch.push {method, args: op}

      for [root, remainder] in resetPaths
        i = remainder.indexOf '.'
        prop = if ~i then remainder.substr 0, i else remainder
        if (parent = after.get root) && (prop of parent)
          patch.push method: 'set', args: ["#{root}.#{remainder}", lookup(remainder, parent)]
        else
          patch.push method: 'del', args: ["#{root}.#{prop}"]

      patch.push item for item in patchConcat
