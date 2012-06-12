0.3.10
- Query re-write.
- Model#subscribe and Model#fetch callbacks now receive a scoped model to the
  query result if subscribing to or fetching a query.
- Local model queries via model.query(...).find()
