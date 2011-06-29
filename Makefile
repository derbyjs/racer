TESTS = $(shell find test/ -name '*.test.coffee')
SERIAL_TESTS = $(shell find test/ -name '*.test.serial.coffee')

test:
	@NODE_ENV=test ./node_modules/expresso/bin/expresso \
		-I lib \
		$(TESTFLAGS) \
		$(TESTS)

serial-test:
	@NODE_ENV=test ./node_modules/expresso/bin/expresso \
		-I lib \
		--serial \
		--timeout 5000 \
		$(TESTFLAGS) \
		$(SERIAL_TESTS)

test-cov:
	@TESTFLAGS=--cov $(MAKE) test

.PHONY: test test-cov serial-test
