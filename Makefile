TESTS = $(shell find test/ -name '*.test.coffee')
SERIAL_TESTS = $(shell find test/ -name '*.test.serial.coffee')

test-async:
	@NODE_ENV=test ./node_modules/expresso/bin/expresso \
		-I lib \
		$(TESTFLAGS) \
		$(TESTS)

test-serial:
	@NODE_ENV=test ./node_modules/expresso/bin/expresso \
		-I lib \
		--serial \
		--timeout 5000 \
		$(TESTFLAGS) \
		$(SERIAL_TESTS)

test: test-async test-serial

test-cov:
	@TESTFLAGS=--cov $(MAKE) test
