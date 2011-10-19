{merge} = require './util'

mutators = module.exports =

  basic:
    set:
      numArgs: 1
      splitArgs: splitArgsDefault = (args) -> [args, []]
    del:
      numArgs: 0
      splitArgs: splitArgsDefault

  array:
    push:
      numArgs: 'variable'
      splitArgs: (args) -> [[], args]
      sliceFrom: 1
      argsToForeignKeys: argsToFKeys = (args, path, $r) ->
        oldArgs = args.slice @sliceFrom
        newArgs = oldArgs.map (refObjToAdd) ->
          if refObjToAdd.$r is undefined
            throw new Error 'Trying to push a non-ref onto an array ref'
          if $r != refObjToAdd.$r
            throw new Error "Trying to use elements of type #{refToObj.$r} with path #{path} that is an array ref of type #{$r}"
          return refObjToAdd.$k
        args.splice @sliceFrom, oldArgs.length, newArgs...
        return args

    pop:
      numArgs: 0
      splitArgs: splitArgsDefault = (args) -> [args, []]

    insertAfter:
      numArgs: 2
      # Extracts or sets the arguments in args that represent indexes
      indexesInArgs: indexInArgs = indexesInArgsForInsert = (args, newVals) ->
        if newVals
          args[0] = newVals[0]
          return args
        return [args[0]]
      splitArgs: splitArgsForInsert = (args) -> [[args[0]], args.slice 1]
      sliceFrom: 2
      argsToForeignKeys: argsToFKeys
      outOfBounds: (arr, afterIndex) -> !(-1 <= afterIndex <= arr.length - 1)
      fn: (arr, afterIndex, value) -> arr.splice afterIndex + 1, 0, value

    insertBefore:
      numArgs: 2
      indexesInArgs: indexInArgs
      splitArgs: splitArgsForInsert
      sliceFrom: 2
      argsToForeignKeys: argsToFKeys
      outOfBounds: (arr, beforeIndex) -> !(0 <= beforeIndex <= arr.length)
      fn: (arr, beforeIndex, value) -> arr.splice beforeIndex, 0, value

    remove:
      numArgs: 2
      indexesInArgs: indexInArgs
      splitArgs: splitArgsDefault
      outOfBounds: (arr, startIndex) ->
        !(0 <= startIndex <= (arr.length && arr.length - 1 || 0))
      fn: (arr, startIndex, howMany) -> arr.splice startIndex, howMany

    splice:
      numArgs: 'variable'
      indexesInArgs: indexInArgs
      splitArgs: (args) -> [args[0..1], args.slice 2]
      sliceFrom: 3
      argsToForeignKeys: argsToFKeys

    unshift:
      numArgs: 'variable'
      splitArgs: splitArgsDefault
      sliceFrom: 1
      argsToForeignKeys: argsToFKeys

    shift:
      numArgs: 0
      splitArgs: splitArgsDefault

    move:
      numArgs: 2
      indexesInArgs: (args, newVals) ->
        if newVals
          args[0..1] = newVals[0..1]
          return args
        return args[0..1]
      splitArgs: splitArgsDefault
      outOfBounds: (arr, from, to) ->
        len = arr.length
        from += len if from < 0
        to += len if to < 0
        return !((0 <= from < len) && (0 <= to < len))
      fn: (arr, from, to) ->
        to += arr.length if to < 0
        # Remove from old location
        [value] = arr.splice from, 1
        # Insert in new location
        arr.splice to, 0, value

all = {}
for name, category of mutators
  all = merge all, category
mutators.all = all
