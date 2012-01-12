compile:
	./node_modules/coffee-script/bin/coffee -bw -o ./lib -c ./src
compile-examples:
	./node_modules/coffee-script/bin/coffee -bcw ./examples/*/*.coffee
macro:
	node ./lib/util/macro.js

MOCHA_TESTS := $(shell find test/ -name '*.mocha.coffee')
MOCHA := $(shell which mocha)
OUT_FILE = "test-output.tmp"

g = "."

test-mocha:
	@NODE_ENV=test $(MOCHA) \
	  --colors \
		--reporter spec \
		--timeout 6000 \
		--grep "$(g)" \
		$(MOCHA_TESTS) | tee $(OUT_FILE)

test-fast:
	@NODE_ENV=test $(MOCHA) \
	  --colors \
		--reporter spec \
		--timeout 1000 \
		--grep "^(?:(?!@slow).)*$$" \
		$(MOCHA_TESTS) | tee $(OUT_FILE)

test: test-mocha
test!:
	@perl -n -e '/\[31m  0\) (.*?).\[0m/ && print "make test g=\"$$1\$$\""' $(OUT_FILE) | sh
