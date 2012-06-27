{filterFnFromQuery} = require '../../lib/computed/filter'
expect = require 'expect.js'

describe 'filter', ->
  describe 'byId', ->
    keyFilter = filterFnFromQuery
      from: 'blogs'
      byId: 'x'
    it 'should return false if key does not match', ->
      expect(keyFilter({id: 'y'})).to.not.be.ok()

    it 'should return true if key does match', ->
      expect(keyFilter({id: 'x'})).to.be.ok()

  describe 'single equals', ->
    describe 'with non-object comparables', ->
      oneEqualsFilter = filterFnFromQuery
        from: 'frameworks'
        equals: { name: 'derby' }

      it 'should return false for non-matching docs', ->
        doc = id: 'x', name: 'rails'
        expect(oneEqualsFilter(doc)).to.not.be.ok()

      it 'should return true for matching docs', ->
        doc = id: 'x', name: 'derby'
        expect(oneEqualsFilter(doc)).to.be.ok()

    describe 'with object comparables', ->
      oneEqualsFilter = filterFnFromQuery
        from: 'athletes'
        equals:
          name:
            first: 'Jeremy'
            last: 'Lin'

      it 'should return false for non-matching docs', ->
        doc =
          id: 'x'
          name:
            first: 'Chris'
            last: 'Paul'
        expect(oneEqualsFilter(doc)).to.not.be.ok()

      it 'should return true for matching docs', ->
        doc =
          id: 'x'
          name:
            first: 'Jeremy'
            last: 'Lin'
        expect(oneEqualsFilter(doc)).to.be.ok()

  describe 'multiple equals', ->
    multiEqualsFilter = filterFnFromQuery
      from: 'celebs'
      equals:
        'name.first': 'michael'
        'name.last': 'jordan'

    it 'should return false for non-matching docs', ->
      doc =
        id: 'x'
        name:
          first: 'michael'
          last: 'jackson'
      expect(multiEqualsFilter(doc)).to.not.be.ok()

    it 'should return true for matching docs', ->
      doc =
        id: 'x'
        name:
          first: 'michael'
          last: 'jordan'
      expect(multiEqualsFilter(doc)).to.be.ok()

  describe 'single notEquals', ->
    describe 'with non-object comparables', ->
      oneNonEqualsFilter = filterFnFromQuery
        from: 'athletes'
        notEquals: { name: 'Roger Federer' }

      it 'should return false for non-matching docs', ->
        doc =
          id: 'x'
          name: 'Roger Federer'
        expect(oneNonEqualsFilter(doc)).to.not.be.ok()

      it 'should return true for matching docs', ->
        doc =
          id: 'x'
          name: 'Rafael Nadal'
        expect(oneNonEqualsFilter(doc)).to.be.ok()

    describe 'with object comparables', ->
      oneNonEqualsFilter = filterFnFromQuery
        from: 'athletes'
        notEquals:
          name:
            first: 'Roger'
            last: 'Federer'

      it 'should return false for non-matching docs', ->
        doc =
          id: 'x'
          name:
            first: 'Roger'
            last: 'Federer'
        expect(oneNonEqualsFilter(doc)).to.not.be.ok()

      it 'should return true for matching docs', ->
        doc =
          id: 'x'
          name:
            first: 'Rafael'
            last: 'Nadal'
        expect(oneNonEqualsFilter(doc)).to.be.ok()

  describe 'multiple notEquals', ->
    multiNonEqualsFilter = filterFnFromQuery
      from: 'trips'
      notEquals:
        origin: 'San Francisco'
        destination: 'Mountain View'

    it 'should return false for non-matching docs', ->
      doc =
        id: 'x'
        origin: 'San Francisco'
        destination: 'Mountain View'
      expect(multiNonEqualsFilter(doc)).to.not.be.ok()

    it 'should return true for matching docs', ->
      doc =
        id: 'x'
        origin: 'Redwood City'
        destination: 'Menlo Park'
      expect(multiNonEqualsFilter(doc)).to.be.ok()

  inequalities =
    gt:
      compare: 21
      matching: 22
      nonMatching: 20
    gte:
      compare: 21
      matching: 21
      nonMatching: 20
    lt:
      compare: 21
      matching: 20
      nonMatching: 22
    lte:
      compare: 21
      matching: 21
      nonMatching: 22

  for condition, {compare, matching, nonMatching} of inequalities
    describe condition, do (condition, compare, matching, nonMatching) -> ->
      ineqFilterParams =
        from: 'users'
      ineqFilterParams[condition] = { age: compare }
      ineqFilter = filterFnFromQuery ineqFilterParams

      it 'should return false for non-matching docs', ->
        doc = id: 'x', age: nonMatching
        expect(ineqFilter(doc)).to.not.be.ok()

      it 'should return true for matching docs', ->
        doc = id: 'x', age: matching
        expect(ineqFilter(doc)).to.be.ok()

  describe 'within', ->
    describe 'with non-object comparables', ->
      withinFilter = filterFnFromQuery
        from: 'users'
        within: { age: [20, 30, 40] }
      it 'should return false for non-matching docs', ->
        doc = id: 'x', age: 50
        expect(withinFilter(doc)).to.not.be.ok()

      it 'should return true for matching docs', ->
        docs = [
          { id: 'a', age: 20 }
          { id: 'b', age: 30 }
          { id: 'c', age: 40 }
        ]
        for doc in docs
          expect(withinFilter(doc)).to.be.ok()
        return

    describe 'with object comparables', ->
      withinFilter = filterFnFromQuery
        from: 'users'
        within:
          pet: [
            { name: 'Banana' }
            { name: 'Squeak' }
          ]

      it 'should return false for non-matching docs', ->
        doc =
          id: 'x'
          pet: { name: 'Pogo' }

        expect(withinFilter(doc)).to.not.be.ok()

      it 'should return true for matching docs', ->
        docA =
          id: 'a'
          pet: { name: 'Banana' }
        docB =
          id: 'b'
          pet: { name: 'Squeak' }
        expect(withinFilter(docA)).to.be.ok()
        expect(withinFilter(docB)).to.be.ok()

  describe 'contains', ->
    describe 'with non-object comparables', ->
      containsFilter = filterFnFromQuery
        from: 'users'
        contains: { nums: [5, 10, 15] }

      it 'should return false for non-matching docs', ->
        docA = id: 'a', nums: [6, 12, 18]
        docB = id: 'b', numss: [5, 10]
        expect(containsFilter(docA)).to.not.be.ok()
        expect(containsFilter(docB)).to.not.be.ok()

      it 'should return true for matching docs', ->
        docA = id: 'a', nums: [5, 10, 15]
        docB = id: 'b', nums: [0, 5, 10, 15, 20]
        expect(containsFilter(docA)).to.be.ok()
        expect(containsFilter(docB)).to.be.ok()

    describe 'with object comparables', ->
      containsFilter = filterFnFromQuery
        from: 'users'
        contains:
          pets: [
            { name: 'Banana' }
            { name: 'Squeak' }
          ]

      it 'should return false for non-matching docs', ->
        docA =
          id: 'a'
          pets: [
            { name: 'Pogo' }
            { name: 'Cookie' }
          ]
        docB =
          id: 'b'
          pets: [
            { name: 'Squeak' }
          ]
        expect(containsFilter(docA)).to.not.be.ok()
        expect(containsFilter(docB)).to.not.be.ok()

      it 'should return true for matching docs', ->
        docA =
          id: 'a'
          pets: [
            { name: 'Banana' }
            { name: 'Squeak' }
          ]
        docB =
          id: 'b'
          pets: [
            { name: 'Pogo' }
            { name: 'Banana' }
            { name: 'Squeak' }
            { name: 'Spotty' }
          ]
        expect(containsFilter(docA)).to.be.ok()
        expect(containsFilter(docB)).to.be.ok()
