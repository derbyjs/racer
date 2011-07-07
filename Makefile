ASYNC_TESTS_FAST = $(shell find test/ -name '*.test.coffee')
SERIAL_TESTS_FAST = $(shell find test/ -name '*.test.serial.coffee')
SERIAL_TESTS_SLOW = $(shell find test/ -name '*.test.serial.slow.coffee')

test-async-fast:
	@NODE_ENV=test ./node_modules/expresso/bin/expresso \
		-I lib \
		$(TESTFLAGS) \
		$(ASYNC_TESTS_FAST)

test-serial-fast:
	@NODE_ENV=test ./node_modules/expresso/bin/expresso \
		-I lib \
		--serial \
		$(TESTFLAGS) \
		$(SERIAL_TESTS_FAST)

test-serial-slow:
	@NODE_ENV=test ./node_modules/expresso/bin/expresso \
		-I lib \
		--serial \
		--timeout 6000 \
		$(TESTFLAGS) \
		$(SERIAL_TESTS_SLOW)

test-async: test-async-fast
test-serial: test-serial-fast test-serial-slow
test-fast: test-async-fast test-serial-fast
test-slow: test-serial-slow
test: test-async-fast test-serial-fast test-serial-slow

test-cov:
	@TESTFLAGS=--cov $(MAKE) test
