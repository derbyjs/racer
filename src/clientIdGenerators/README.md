Each file in this directory represents a client id generation strategy. Each
file exports a single function that takes an optional single options argument
and returns a the client id generation function. The returned function must
have a signature of:

    function (callback) {
    }

where callback has a function signature of

    function callback (err, clientId) {
    }

## Client Id Generator Strategies

- rfc4122.v4 delegates to broofa's node-uuid module. It is the default setting in
             racer
- mongo      delegates to the npm mongodb module's BSON UUID generation
- redis      uses an atomically incrementing `clientClock` key
