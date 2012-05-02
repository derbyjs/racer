Filter = require '../../lib/queries/Filter'
expect = require 'expect.js'

describe 'Filter', ->
  describe '#test', ->
    it 'should return false for non-namespace matches', ->
      f = new Filter
        from: 'blogs'
      expect(f.test({id: 'x'}, 'users.x')).to.not.be.ok()

    describe 'for namespace matches', ->
      it 'should return true if only testing for namespace match', ->
        f = new Filter
          from: 'blogs'
        expect(f.test({id: 'x'}, 'blogs.x')).to.be.ok()

      describe 'byKey', ->
        keyFilter = new Filter
          from: 'blogs'
          byKey: 'x'
        it 'should return false if key does not match', ->
          expect(keyFilter.test({id: 'y'}, 'blogs.y')).to.not.be.ok()

        it 'should return true if key does match', ->
          expect(keyFilter.test({id: 'x'}, 'blogs.x')).to.be.ok()

      describe 'single equals', ->
        describe 'with non-object comparables', ->
          oneEqualsFilter = new Filter
            from: 'frameworks'
            equals: { name: 'derby' }

          it 'should return false for non-matching docs', ->
            doc = id: 'x', name: 'rails'
            expect(oneEqualsFilter.test(doc, 'frameworks.x')).to.not.be.ok()

          it 'should return true for matching docs', ->
            doc = id: 'x', name: 'derby'
            expect(oneEqualsFilter.test(doc, 'frameworks.x')).to.be.ok()

        describe 'with object comparables', ->
          oneEqualsFilter = new Filter
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
            expect(oneEqualsFilter.test(doc, 'athletes.x')).to.not.be.ok()

          it 'should return true for matching docs', ->
            doc =
              id: 'x'
              name:
                first: 'Jeremy'
                last: 'Lin'
            expect(oneEqualsFilter.test(doc, 'athletes.x')).to.be.ok()

      describe 'multiple equals', ->
        multiEqualsFilter = new Filter
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
          expect(multiEqualsFilter.test(doc, 'celebs.x')).to.not.be.ok()

        it 'should return true for matching docs', ->
          doc =
            id: 'x'
            name:
              first: 'michael'
              last: 'jordan'
          expect(multiEqualsFilter.test(doc, 'celebs.x')).to.be.ok()

      describe 'single notEquals', ->
        describe 'with non-object comparables', ->
          oneNonEqualsFilter = new Filter
            from: 'athletes'
            notEquals: { name: 'Roger Federer' }

          it 'should return false for non-matching docs', ->
            doc =
              id: 'x'
              name: 'Roger Federer'
            expect(oneNonEqualsFilter.test(doc, 'athletes.x')).to.not.be.ok()

          it 'should return true for matching docs', ->
            doc =
              id: 'x'
              name: 'Rafael Nadal'
            expect(oneNonEqualsFilter.test(doc, 'athletes.x')).to.be.ok()

        describe 'with object comparables', ->
          oneNonEqualsFilter = new Filter
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
            expect(oneNonEqualsFilter.test(doc, 'athletes.x')).to.not.be.ok()

          it 'should return true for matching docs', ->
            doc =
              id: 'x'
              name:
                first: 'Rafael'
                last: 'Nadal'
            expect(oneNonEqualsFilter.test(doc, 'athletes.x')).to.be.ok()

      describe 'multiple notEquals', ->
        multiNonEqualsFilter = new Filter
          from: 'trips'
          notEquals:
            origin: 'San Francisco'
            destination: 'Mountain View'

        it 'should return false for non-matching docs', ->
          doc =
            id: 'x'
            origin: 'San Francisco'
            destination: 'Mountain View'
          expect(multiNonEqualsFilter.test(doc, 'trips.x')).to.not.be.ok()

        it 'should return true for matching docs', ->
          doc =
            id: 'x'
            origin: 'Redwood City'
            destination: 'Menlo Park'
          expect(multiNonEqualsFilter.test(doc, 'trips.x')).to.be.ok()

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
          ineqFilter = new Filter ineqFilterParams

          it 'should return false for non-matching docs', ->
            doc = id: 'x', age: nonMatching
            expect(ineqFilter.test(doc, 'users.x')).to.not.be.ok()

          it 'should return true for matching docs', ->
            doc = id: 'x', age: matching
            expect(ineqFilter.test(doc, 'users.x')).to.be.ok()

      describe 'within', ->
        describe 'with non-object comparables', ->
          withinFilter = new Filter
            from: 'users'
            within: { age: [20, 30, 40] }
          it 'should return false for non-matching docs', ->
            doc = id: 'x', age: 50
            expect(withinFilter.test(doc, 'users.x')).to.not.be.ok()

          it 'should return true for matching docs', ->
            docs = [
              { id: 'a', age: 20 }
              { id: 'b', age: 30 }
              { id: 'c', age: 40 }
            ]
            for doc in docs
              expect(withinFilter.test(doc, "users.#{doc.id}")).to.be.ok()
            return

        describe 'with object comparables', ->
          withinFilter = new Filter
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

            expect(withinFilter.test(doc, 'users.x')).to.not.be.ok()

          it 'should return true for matching docs', ->
            docA =
              id: 'a'
              pet: { name: 'Banana' }
            docB =
              id: 'b'
              pet: { name: 'Squeak' }
            expect(withinFilter.test(docA, 'users.a')).to.be.ok()
            expect(withinFilter.test(docB, 'users.b')).to.be.ok()

      describe 'contains', ->
        describe 'with non-object comparables', ->
          containsFilter = new Filter
            from: 'users'
            contains: { nums: [5, 10, 15] }

          it 'should return false for non-matching docs', ->
            docA = id: 'a', nums: [6, 12, 18]
            docB = id: 'b', numss: [5, 10]
            expect(containsFilter.test(docA, 'users.a')).to.not.be.ok()
            expect(containsFilter.test(docB, 'users.b')).to.not.be.ok()

          it 'should return true for matching docs', ->
            docA = id: 'a', nums: [5, 10, 15]
            docB = id: 'b', nums: [0, 5, 10, 15, 20]
            expect(containsFilter.test(docA, 'users.a')).to.be.ok()
            expect(containsFilter.test(docB, 'users.b')).to.be.ok()

        describe 'with object comparables', ->
          containsFilter = new Filter
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
            expect(containsFilter.test(docA, 'users.a')).to.not.be.ok()
            expect(containsFilter.test(docB, 'users.b')).to.not.be.ok()

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
            expect(containsFilter.test(docA, 'users.a')).to.be.ok()
            expect(containsFilter.test(docB, 'users.b')).to.be.ok()
