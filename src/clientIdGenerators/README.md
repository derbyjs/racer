Each file in this directory represents a client id generation strategy. Each
file exports a single function that takes an optional single options argument
and returns a the client id generation function. The returned function must
have a signature of:

    function (callback) {
    }

where callback has a function signature of

    function callback (err, clientId) {
    }
