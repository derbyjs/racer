publish / subscribe
====================

The pubSub module mixes in pubsub capabilities into the Model and Store.

The Model mixin:
1. Creates a `subscribe` and `publish` method
2. Has its connection (socket.io) listen for events:
   - "resyncWithStore"
   - "addDoc"
   - "rmDoc"

## Race conditions

1. ClientA sends a subscription request to pubSub
2. ClientA sends a request for data to the db
3. ClientB is mutating data. It publishes to pubSub. The message is
   published to any subscribers at this time. It simultaneously sends
   a write request to the db.
4. ClientA's requests to pubSub and the db occur afterwards.
5. ClientB's write to the db succeeds
6. However, now we're in a state where ClientA has a copy of the data
   without the mutation.

Solution: We take care of this after the replicated data is sent to the
browser. The browser model asks the server for any updates like this it
may have missed.

## Query PubSub approach

Every mutation returns a full doc or docs. We pass that doc and the diff
through a subset of queries to decide (a) which queries to remove this doc
from and (b) which queries to add this doc to

## Cases for mutations impacting paginated queries

```

   <page prev> <page curr> <page next>
                                         do nothing to curr

+  <page prev> <page curr> <page next>
                   +  <<<<<<<  -         push to curr from next

+  <page prev> <page curr> <page next>
       +   <<<<<   -                     unshift to curr from prev

+  <page prev> <page curr> <page next>
       -                                 shift from curr to prev
                                         push to curr from right

+  <page prev> <page curr> <page next>
       -   >>>>>   +                     shift from curr to prev
                                         insert + in curr

+  <page prev> <page curr> <page next>
       -   >>>>>>>>>>>>>>>>>   +         shift from curr to prev
                                         push from next to curr

+  <page prev> <page curr> <page next>
       +                                 unshift to curr from prev
                                         pop from curr to next

+  <page prev> <page curr> <page next>
                   +                     pop from curr to next

   <page prev> <page curr> <page next>
                               -/+       do nothing to curr

+  <page prev> <page curr> <page next>
                   -><-                  re-arrange curr members
```
