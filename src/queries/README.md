Queries
=======

## Getting Started

Your first step in working with queries should be to declare query motifs of
interest to your application, with a Store instance.

```javascript
var store = racer.createStore();
// Note that in Derby apps, this would instead be:
//
//     var store = app.createStore();
//
// where app is your Derby app.

store.query.expose('users', 'whoLoggedInSince', function (since) {
  return this.where('lastLogin').gte(since);
});
```

You can read this as:

    Expose a query motif named "whoLoggedInSince" to the API that generates queries
    over documents in the "users" namespace. The generated query will match users
    that have a "lastLogin" value greater than or equal to `since`.

Once this query motif is exposed, you will be able to create queries with your
model via the API:

```javascript
var month = 30 * 24 * 3600 * 1000;
var activeUsersQuery = model.query('users').whoLoggedInSince(+new Date - month);
```

Model has access to every query motif declared by `store.query.expose`, so that
is why we have access to a `whoLoggedInSince` method above.

The snippet above returns a query over all users who have logged in since a month ago.

Such a query is not run immediately. To run the query, we pass the query to
Model#fetch or Model#subscribe, which both lazily run the query to find the
query results and load them into the model.

Model#fetch fetches the documents that satisfy the query and passes a scoped
model representing the list of results to Model#fetch's callback.

```javascript
model.fetch(activeUsersQuery, function (err, activeUsers) {
  // activeUsers is a scoped model

  console.log(activeUsers.get()); // prints the results of the query

});
```

Please note again that Model#fetch fetches *only* a snapshot of the results
from the Store. Model#fetch will not automatically keep those results
dynamically up-to-date.

Enter Model#subscribe ...

Model#subscribe fetches the query results *and* also subscribes the Model to
any changes to the query results automatically. This means that the query
results are always kept up to date without the developer having to write the
code to sync changes to the result set. The developer need not worry about
figuring out which documents to add or remove from the model. Racer will
automatically figure this out and automatically add this to the model and
subsequently update any dependents in realtime.

```javascript
model.subscribe(activeUsersQuery, function (err, activeUsers) {
  console.log(activeUsers.get()); // prints the results of the query
});
```

This is also accessible via Model#fromQueryMotif:

```javascript
var model = store.createModel();

var activeUsersQuery = model.fromQueryMotif('users', 'activeUsers');
model.subscribe(activeUsersQuery, function (err, activeUsers) {
  console.log(activeUsers.get()); // prints the results of the query
});
```

Here's another example, with the code all here for a concise overview of how to
use these concepts and methods together.

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

With query motifs, you can generate all sorts of queries in a rich,
semantically meaningful way. Inside the `store.query.expose` callback,
`this` is a `QueryBuilder` instance that provides a fluent and chainable
interface for building up queries.

```javascript

store.query.expose('users', 'usersWithName', function (name) {
  return this.where('name').equals(name);
});

store.query.expose('users', 'withId', function (id) {
  return this.users.byId(id);
});

store.query.expose('blogs', 'authoredBy', function (userId) {
  return this.where('authorId').equals(userId);
});

store.query.expose('items', 'taggedWithAny', function (tags) {
  return this.where('tags').in(tags);
});
```

### Transformations

The convenient querying interface available inside of store.query.expose
callbacks can also be used with data already loaded into your Model. This helps
you to slice, dice, filter, and sort your data in your Model. These
transformation results can be assigned to a Model ref, which you can use to
refer to the results later on. Transformations are created via Model#filter and
Model#sort.

```javascript

var derbyPosts = model.filter('posts').where('tags').contains(['Derby']);
// derbyPosts is a transformation, not a scoped model.
// This means that you can still chain transformation functions to it to build
// out a more descriptive transformation
derbyPosts.sort(['id', 'asc']);

// While derbyPosts are not a scoped Model instance, it does quack like a Model
// in some ways. For instance, you can call Model#get to see the value of the
// result. Invoking `get` on the transformation will lazily evaluate the
// transformation.
console.log(derbyPosts.get());

// You always will want to assign the transformation to a Model ref, so you can
// use the results with a human-readable path (here '_derbyPosts') in your
// views.
var derbyPostsRef = model.ref('_derbyPosts', postsWithDerby);

// derbyPostsRef is a scoped Model

// In addition to a chainable interface, you can also define a transformation
// filter via an Object argument that mirrors the query API.
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

`sort` and `filter` can also take functions that represent a comparator and
filter function respectively.

```javascript
model
  .filter('tasks', function (task) {
    return task.isSpecial;
  })
  .sort(function (taskA, taskB) {
    return taskB.priority - taskA.priority;
  });
```

Transformations also work directly on scoped models. This makes transformations
even easier to use.

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
  // Very niiice!
  var filteredResults = model.ref('_filteredResults',
    results.filter({ tags: { contains: ['important'] } })
  );
});
```

## Architecture

- **Filter Functions**

  A filter function returns true if a document is allowed in the set it
  encompasses and false if not. Filter functions form the basis of membership
  decision-making for in-Model filtering, MemoryQuery logic on the server when
  using the in-memory database, and guard logic used by QueryNodes in a
  QueryHub to help determine which transactions to propagate to a query's
  subscribers.

- **QueryBuilder**

  Provide a fluent interface to build query json objects.

- **TransformBuilder**

  Provide a fluent interface to filter Objects and Arrays stored in your Model
  data.

- **MemoryQuery**

  Queries that can act over data in memory. MemoryQuery instances are used by
  the DbMemory database adapter, by QueryNodes, and in the browser for
  part of the in-browser transformation results computation.

- **QueryMotif**

  A QueryMotif is the way that you define which query patterns are accessible
  to your application. QueryMotifs are defined via
  `store.query.expose(namespace, motifName, fn)` where `namespace` is the name of
  the top level collection of documents, `motifName` is the name of the
  QueryMotif, and `fn` takes motif inputs and returns a QueryBuilder that is a
  concrete query built from the QueryMotif definition and the specific inputs.
  Calling `store.query.expose(namespace, motifName, fn)` creates methods on
  `model.query(namespace)` named after `motifName` and that take arguments that
  map 1-to-1 with the `fn` arguments. For example:

  ```javascript
  store.query.expose('users', 'withFirstName', function (fname) {
    return this.where('name.first').equals(fname);
  });
  ```

  creates a method `withFirstName`:

  ```javascript
  var nateUsersQuery = model.query('users').withFirstName('Nate');
  ```

- **QueryCoordinator** (Unimplemented)

  Routes queries (for subscribes and fetches) to the proper QueryHub.
  Eventually, when we shard our queries across multiple QueryHubs, then
  QueryCoordinators figure out to which QueryHubs to send the subscribe or
  fetch action. We can eventually incorporate CAP parameters to tune typical R
  and W CAP parameters that control consistency vs availability. Currently,
  QueryHub is used for QueryCoordinators, since we are still only
  single-server.

- **QueryHub**

  A repository in the cloud, of queries. It is made up of QueryNode
  instances.

- **QueryNode**

  A node in a QueryHub repository. It represents a query, that
  query's cached results, and information required for managing
  publish/subscribe over queries.

- **PaginatedQueryNode** (Incomplete)

  Like a QueryNode, but handles the special case of pagination.

- **QueryRegistry**

  A container of queries from which a Model or Store can add, retrieve, and
  remove queries, using a query tuple. A query tuple is an Array of the form
  [ns, {<queryMotif>: queryArgs, ...}, queryId] and is a natural representation of a query
  because queries are only accessible behind a query motif.

- **QueryMotifRegistry**

  A container of query motifs declared by Store and inherited by Model. Query
  motifs are named references to functions that return a QueryBuilder instance
  given some parameters that get passed to the QueryBuilder inside the function.


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

# Other Ideas

IMPORTANT! Everything written from here on forward is not implemented but just
documentation of some other ideas.

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
