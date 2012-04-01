compile:
	./node_modules/coffee-script/bin/coffee -bw -o ./lib -c ./src ./dev
compile-examples:
	./node_modules/coffee-script/bin/coffee -bcw ./examples/*/*.coffee
macro:
	./scripts/watch-macro

ROOT := $(shell pwd)
MOCHA_TESTS := $(shell find test/ -name '*.mocha.coffee')
MOCHA := ./node_modules/mocha/bin/mocha --compilers coffee:coffee-script
OUT_FILE = "test-output.tmp"

g = "."

test-mocha:
	$(ROOT)/scripts/prepublish;
	@NODE_ENV=test $(MOCHA) \
		--grep "$(g)" \
		$(MOCHA_TESTS) | tee $(OUT_FILE)

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
		$(MOCHA_TESTS) | tee $(OUT_FILE)

test: test-mocha
test-all: test-mocha test-external
test!:
	@perl -n -e '/\[31m  0\) (.*?).\[0m/ && print "make test g=\"$$1\$$\""' $(OUT_FILE) | sh
