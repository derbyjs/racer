0.3.11
- This was mostly a re-write for a more robust query, filter, and sort API
- Model#subscribe and Model#fetch callbacks now receive a scoped model to the
  query result if subscribing to or fetching a query.
- QueryMotifs: Queries must be declared via `store.query.expose`
- Local filtering and sorting API over data
