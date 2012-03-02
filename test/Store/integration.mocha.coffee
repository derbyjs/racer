{run} = require '../util/store'

allModes = ({mode} for mode in ['lww', 'stm'])

run 'Store integration Memory', allModes, require('./integration')
