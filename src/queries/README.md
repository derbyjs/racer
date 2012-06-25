Queries
=======

## Getting Started

Your first step in working with queries should be to declare query motifs of
interest to your application, with a Store instance.

```javascript
var store = racer.createStore();

store.query.expose('users', 'active', function () {
  var month = 30 * 24 * 3600 * 1000;
  return this.where('lastLogin').gte(+new Date - MONTH);
});
```

The code above only associates a query with a name. It does not run the query.
To run the query, we pass the query name to Model#subscribe or Model#fetch.

Model#fetch fetches the documents that satisfy the query and passes a scoped
model representing the list of results to Model#fetch's callback.


Model#subscribe fetches the query results *and* also subscribes the Model to
any changes to the query results automatically. This means that the query
results are always kept up to date without the developer having to write the
code to sync changes to the result set. The developer need not worry about
figuring out which documents to add or remove from the model. Racer will
automatically figure this out and automatically add this to the model and
subsequently updating any dependents in realtime.

```javascript
var model = store.createModel();

var activeUsersQuery = model.fromQueryMotif('users', 'activeUsers');
model.subscribe(activeUsersQuery, function (err, activeUsers) {
  console.log(activeUsers.get()); // prints the results of the query
});
```

There is also a more fluent, chainable approach to making concrete queries from
query motifs.

```javscript
var model = store.createModel();

// Model inherits every query motif declared by store.query.expose, so that is
// why we have access to an `activeUsers` method here.
var activeUsersQuery = model.query('users').activeUsers();
model.subscribe(activeUsersQuery, function (err, activeUsers) {
  console.log(activeUsers.get()); // prints the results of the query
});
```

In contrast, Model#fetch will only fetch a snapshot of the results from the
Store, but it will not automatically keep those results dynamically up-to-date.

```javascript
model.fetch(activeUsersQuery, function (err, activeUsers) {
  console.log(activeUsers.get()); // print the results of the queery
});
```

You can also pass arguments to a query motif. This can be very useful and is a
common pattern. For instance:

```javascript
// On the server
store.query.expose('users', 'olderThan', function (age) {
  return this.where('age').gt(age);
});
```

```javascript
// In your app code
var eligibleVotersQuery = model.query('users').olderThan(20);
model.subscribe(eligibleVotersQuery, function (err, eligibleVoters) {
  console.log(eligibleVoters.get()); // prints the results of the query

  // Declare a ref, so we can bind results via private path '_eligibleVoters'
  model.ref('_eligibleVoters', eligibleVoters);
});
```

Inside the `store.query.expose` callback, `this` is a `QueryBuilder` instance
that provides a fluent and chainable interface for building up queries.

```javascript

store.query.expose('users', 'usersWithName', function (name) {
  return this.where('name').equals('Brian');
});

store.query.expose('users', 'withId', function (id) {
  return this.users.byKey(id);
});

store.query.expose('blogs', 'authoredBy', function (userId) {
  return this.where('authorId').equals(userId);
});

store.query.expose('items', 'taggedWithAny', function (tags) {
  return this.where('tags').in(['derby', 'racer']);
});
```

### Transformations

The convenient querying interface available inside of store.query.expose
callbacks is also available to developers in data already loaded into a client
via a combination of Model#ref and Model#filter or Model#sort.

```javascript

var computation = model.filter('posts').where('tags').contains(['Derby']);
var derbyPosts = model.ref('_derbyPosts', computation);

// derbyPosts is a scoped model

var importantTasks = model.ref('_importantTasks',
  model.filter('tasks', {
    where: {
      tags: { contains: ['important'] }
    }
  })
);

// importantTasks is a scoped model
console.log(importantTasks.get());

var topTask = model.ref('_topTask',
  model.sort('tasks', ['votes', 'desc']).one()
);

// topTask is a scoped model
console.log(topTask.get());
```

This also works on scoped models.

```javascript
var tasks = model.at('tasks')
var importantTasks = model.ref('_importantTasks',
  tasks.filter({where: { tags: { contains: ['important'] } } })
);
```

In addition to filtering over a top-level collection namespace, filters can
also work over an arbitrarily nested document tree or an arbitrarily nested
document array. The corollary is that it is possible to filter on any query
results or the results of a different filter.

```javascript
model.subscribe(query, function (err, results) {
  var filteredResults = model.ref('_filteredResults',
    results.filter({ tags: { contains: ['important'] } })
  );
});
```

In the future, you will be able to define filters with an anonymous function.

```javascript
var completedTasks = model.ref('_completedTasks',
  model.filter('tasks', function (task) {
    return task.completed;
  })
);
```

## Architecture

- QueryBuilder, TransformBuilder
  Provide a fluent interface to build query json objects.

- Filter Functions
  A filter function returns true if a document is allowed in the set it
  encompasses and false if not. Filter functions form the basis of membership
  decision-making for in-Model filtering, MemoryQuery logic on the server when
  using the in-memory database, and guard logic used by QueryNodes in a
  QueryHub to help determine which transactions to propagate to a query's
  subscribers.

- MemoryQuery
  Queries that can act over data in memory. MemoryQuery instances are used by
  the DbMemory database adapter, by QueryNodes, and in the browser for
  in-browser filters.

- QueryCoordinator (Unimplemented)
  Routes queries (for subscribes and fetches) to the proper QueryHub.
  Eventually, when we shard our queries across multiple QueryHubs, then
  QueryCoordinators figure out to which QueryHubs to send the subscribe or
  fetch action. We can eventually incorporate CAP parameters to tune typical R
  and W CAP parameters that control consistency vs availability. Currently,
  QueryHub is used for QueryCoordinators, since we are still only
  single-server.

- QueryHub
  A repository in the cloud, of queries. It is made up of QueryNode
  instances.

- QueryNode
  A node in a QueryHub repository. It represents a query, that
  query's cached results, and information required for managing
  publish/subscribe over queries.

- PaginatedQueryNode (Incomplete)
  Like a QueryNode, but handles the special case of pagination.

- QueryRegistry
  A container of queries from which a Model or Store can add, retrieve, and
  remove queries, using a query tuple. A query tuple is an Array of the form
  [ns, {<queryMotif>: queryArgs, ...}, queryId] and is a natural representation of a query
  because queries are only accessible behind a query motif.

- QueryMotifRegistry
  A container of query motifs declared by Store and inherited by Model. Query
  motifs are named references to functions that return a QueryBuilder instance
  given some parameters that get passed to the QueryBuilder inside the function.

- Query Motifs
  TODO Add explanation here.


The advantages of using query motifs are:

- More efficient than query patterns. With query patterns, you would have to
  figure out which patterns match the query. This could be O(N) on the number
  of patterns, whereas query motifs are O(1) to figure out where to find the
  auth code for the query.
- DRY - If you want to update a query that represents "userMessages", you could
  do so once, without having to change the abstraction that you are subscribing
  to (still "userMessages" everywhere you subscribe or fetch that data). On the
  other hand, allowing more ad-hoc queries as needed in your app would
  necessitate updating the query invocation at every subscribe and fetch in
  your app.
- It is obvious what parameters could be used to validate or auth against. The
  parameters are just the callback parameters of store.query.expose.

### Other Ideas

- Queries with dynamically changing parameter values
- Query Motif Composability
- Immediately live queries
- Different ways to declare query motifs
- Model#filterFnFromQuery could be Model#filter with arity 2 (vs arity 1)

      var results = model.filter('candidates', {
        where: { age: { gt: 40 } }
      });

- Automatically run a filter by assigning a filter to a ref (instead of
  invoking FilterBuilder#run())

      var filter = model.filter('candidates').where('age').gt(40);
      var filteredResults = model.ref('_filteredResults', filter);

If we make gt, lt, gte, etc query motifs, then we could effectively secure
ad-hoc queries and use a pattern of querying that we naturally tended towards
in the beginning.

#### Queries with dynamically changing parameter values

```coffee
# The concept of filters could possibly be extended to app-defined queries.
store.query.expose 'onResults', (results) ->
  @query(results).where('age').gt(40).one()
```

#### Query Motif Composability

```coffee
store.query.expose 'olderThan', (age) ->
  @query('users').where('age').gt(age)

store.query.expose 'users', 'olderThan', (age) ->
  @query().where('age').gt(age)

store.query.expose 'youngerThan', (age) ->
  @query('users').where('age').lt(age)

model.query('users').olderThan(20).youngerThan(30)

store.query.expose 'twenties', (age) ->
  @query().olderThan(20).youngerThan(30)

model.query('users').twenties()
```

#### Immediately live queries

```javascript

// TODO This feature is desired but not yet implemented
  // In addition to returning a model alias of a result set, you can also have
  // the query subscribe to results of data that is not already loaded into the
  // page. This is useful when you can get immediate results to display based on
  // data already loaded into your model, instead of waiting for a subscribe
  // callback which is only invoked after a round trip to the server.

  var resE = model.query('users').where('age').gte(25).find();
  model.subscribe(resE);

// You can also scope your queries to results of another query
var queryF = model.query('users').where('age').gte(22);
model.subscribe(queryF, function (err, results) {
  var importantRacerItems = model.query(results).where('tags').contain(['priority', 'racer']);
});

// Queries can also work on arrays of documents that are pointed to by private
// or public paths.

```

#### Different ways to declare query motifs

```javascript
store.query.expose('users', 'admin', {
  where: {
    roles: { in: ['admin'] }
  }
});
```

```javascript
store.query.expose('users', 'admin').where('roles').in(['admin']);
```

```javascript
store.query.expose('users', 'twenties').olderThan(19).youngerThan(30);
```

#### Misc


```javascript
var filter = model.filterStream(filterFn);
var sort = model.sortStream(sortFn);
var ref = model.ref('_importantTasks');
model.stream('tasks').pipe(filter).pipe(sort).pipe(head).pipe(ref);


replica.filter(x).sort(y).pipe(newReplica)


replica.scope(x).filter(y).sort(z).pipe(ref)
```


## Discarded Ideas

This was an idea for protecting "families" of queries.

```coffee
queryPattern = model.queryPattern('users')
  .where('role').within(freevar())
  .where('ownerId').equals(freevar())
  .where('age')
    .lte(freevar('ageUpper'))
    .gte(freevar('ageLower'))

store.allow queryPattern, (freeVars, session) ->
  return freeVars.ownerId == session.userId

# There would be idiomatic shortcuts for common query pattern scenarios.
queryPattern = model.queryPattern('users')
  .where('age').lt(freevar(Number, {lt: 3}))

queryPattern = model.queryPattern('users')
  .where('role').within( (arr) ->
    ~arr.indexOf('candidates')
  )
  .where('ownerId').equals(freevar)

```

We decided to discard this because:

- The queryPattern syntax makes it hard to discern immediately which variables
  in the query can vary (i.e., freevar).
- Changing a query in one place might require you to remember to update a
  queryPattern in another file.


Another idea was to do away with query patterns and to infer a query pattern
from a concrete query in the app.

```coffee
exports.queryOne = model.query 'users',
  where:
    role: within: ['user', 'admin']
    ownerId: model.session.id
    age:
      gte: 20
      lte: 30

```

This also was discarded because:

- It was not immediate
