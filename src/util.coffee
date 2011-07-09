exports.onServer = typeof window == 'undefined'

# Test to see if path name contains a segment that starts with an underscore.
# Such a path is private to the current session and should not be stored
# in persistent storage or synced with other clients.
exports.publicPath = (name) -> ! /(^_)|(\._)/.test name