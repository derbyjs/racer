# Racer change history

## 0.3.13
Mostly bug fixes

- Simple implementation of count() query aggregation
- Support for exists() query
- add waitFetch convenience method for fetching only after connecting
- Fix specifying Browserify debug mode
- Fix re-initailzation of queries in browser
- Fix lots of session bugs
- Fix lots of query bugs

## 0.3.12
Add initial support for authorization and access control

- Initial support for auth. See https://github.com/codeparty/racer/blob/master/src/accessControl/README.md
- New store.sessionMiddleware() with support for auth. Remove old racer.session middleware
- New store.modelMiddleware(), which adds a req.getModel() method
- Add racer.logPlugin for better debugging console output

## 0.3.11
This was mostly a re-write for a more robust query, filter, and sort API.

- Queries must be declared via `store.query.expose()`
- Implemment local filtering and sorting API over data with `model.filter()` and `model.sort()`
- `model.subscribe()` and `model.fetch()` callbacks now receive a scoped model to the
  query result if subscribing to or fetching a query
- Implemment `model.add()` method for adding objects to a collection. It generates a `model.id()` and saves the object with that id as its property automatically
- Update `model.ref()` method signature for scoped models to require a `to` argument that is a subpath
- Fix bug with commit ordering for mutations that are the result of another mutation's event emissions
- Start converting Coffee source files to JS
