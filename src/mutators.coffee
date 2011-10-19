{merge} = require './util'

mutators = module.exports =

  basic:
    set:
      numArgs: 1
      splitArgs: splitArgsDefault = (args) -> [args, []]
    del:
      numArgs: 0
      splitArgs: splitArgsDefault
  
  ot:
    insertOT: {}
    delOT: {}

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
      splitArgs: splitArgsDefault

    insertAfter:
      numArgs: 2
      # Extracts or sets the arguments in args that represent indexes
      indexArgs: [0]
      splitArgs: splitArgsForInsert = (args) -> [[args[0]], args.slice 1]
      sliceFrom: 2
      argsToForeignKeys: argsToFKeys

    insertBefore:
      numArgs: 2
      indexArgs: [0]
      splitArgs: splitArgsForInsert
      sliceFrom: 2
      argsToForeignKeys: argsToFKeys

    remove:
      numArgs: 2
      indexArgs: [0]
      splitArgs: splitArgsDefault

    splice:
      numArgs: 'variable'
      indexArgs: [0]
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
      indexArgs: [0, 1]
      splitArgs: splitArgsDefault

all = {}
for name, category of mutators
  all = merge all, category
mutators.all = all
