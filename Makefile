compile-examples:
	./node_modules/coffee-script/bin/coffee -bcw ./examples/*/*.coffee

ROOT := $(shell pwd)
MOCHA_TESTS := $(shell find test/ -name '*.mocha.coffee')
MOCHA := ./node_modules/mocha/bin/mocha
PLATO := ./node_modules/.bin/plato
OUT_FILE = "test-output.tmp"
OUT_REPORT = "report"
JSHINTRC = ".jshintrc"
REPORTER = "spec"

g = "."

test-mocha:
	@NODE_ENV=test $(MOCHA) \
		--reporter $(REPORTER) \
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

test-cov: lib-cov
	@RACER_COV=1,@NODE_ENV=test \
		$(MOCHA) $(MOCHA_TESTS) \
		--reporter html-cov > coverage.html

report:
	$(PLATO) -r -l $(JSHINTRC) -d $(OUT_REPORT) lib/

test: test-mocha
test-all: test-mocha test-external
test!:
	@perl -n -e '/\[31m  0\) (.*?).\[0m/ && print "make test g=\"$$1\$$\""' $(OUT_FILE) | sh

lib-cov:
	@jscoverage --no-highlight lib lib-cov

clean:
	rm -rf report/
	rm -rf lib-cov/
	rm -f coverage.html
	rm -f $(OUT_FILE)
