compile-examples:
	./node_modules/coffee-script/bin/coffee -bcw ./examples/*/*.coffee

ROOT := $(shell pwd)
MOCHA_TESTS := $(shell find test/ -name '*.mocha.coffee')
MOCHA := ./node_modules/mocha/bin/mocha

g = "."

test-mocha:
	@NODE_ENV=test $(MOCHA) \
		--grep "$(g)" \
		$(MOCHA_TESTS)

test-external:
	cd $(ROOT)/node_modules/racer-journal-redis/; make test
	cd $(ROOT)/node_modules/racer-pubsub-redis/; make test
	cd $(ROOT)/node_modules/racer-db-mongo/; make test
	cd $(ROOT)

test-fast:
	@NODE_ENV=test $(MOCHA) \
	  --colors \
		--reporter spec \
		--timeout 500 \
		--grep "^(?:(?!@slow).)*$$" \
		$(MOCHA_TESTS)

test: test-mocha
test-all: test-mocha test-external
