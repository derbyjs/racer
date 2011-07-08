_ = require './util'

if _.onServer
  Store = require './server/Store'
  MemoryAdapter = require './server/adapters/Memory'
  Stm = require './server/Stm'
  DataSupervisor = require './server/DataSupervisor'

# Server vs Browser
# - Server should not keep track of local _data (only by proxy if using Store MemoryAdapter); Browser should
# - Server should connect to DataSupervisor; Browser should connect to socket.io endpoint on server
# - Server should not deal with speculative models; Browser should
#   - Perhaps a special Store can control this?
# - Keeping track of transactions?
#
# Perhaps all server Store types have a Stm component. Then the
# abstraction is we just are interacting with some data store
# with STM capabilities