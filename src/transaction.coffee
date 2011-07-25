# TODO Add set version of methods
module.exports =
  base: (txn) -> txn[0]
  id: (txn) -> txn[1]
  method: (txn) -> txn[2]
  args: (txn) -> txn.slice 3
  path: (txn) -> txn[3]
  clientId: (txn) -> @id(txn).split('.')[0]
