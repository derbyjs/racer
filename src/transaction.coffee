# TODO Add set version of methods
module.exports =
  base: (txn) -> txn[0]
  id: (txn) -> txn[1]
  method: (txn) -> txn[2]
  args: (txn) -> txn.slice 3
  path: (txn) -> txn[3]
  
  # Test to see if path name contains a segment that starts with an underscore.
  # Such a path is private to the current session and should not be stored
  # in persistent storage or synced with other clients.
  publicPath: (name) -> ! /(^_)|(\._)/.test name
