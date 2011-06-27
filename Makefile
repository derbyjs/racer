TESTS = $(shell find test/ -name 'txn.test.coffee')

test:
	@NODE_ENV=test ./node_modules/expresso/bin/expresso \
		-I lib \
		$(TESTFLAGS) \
		$(TESTS)

test-cov:
	@TESTFLAGS=--cov $(MAKE) test

.PHONY: test test-cov
