{merge} = require './util'

mutators = module.exports =

  basic:
    set: {}
    del: {}
  
  ot:
    insertOT: {}
    delOT: {}

  array:
    push:
      insertArgs: 1

    pop: {}

    insertAfter:
      # Extracts or sets the arguments in args that represent indexes
      indexArgs: [1]
      insertArgs: 2

    insertBefore:
      indexArgs: [1]
      insertArgs: 2

    remove:
      indexArgs: [1]

    splice:
      indexArgs: [1]
      insertArgs: 3

    unshift:
      insertArgs: 1

    shift: {}

    move:
      indexArgs: [1, 2]

all = {}
for name, category of mutators
  all = merge all, category
mutators.all = all
