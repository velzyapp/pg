DB=velzy
BUILD=${CURDIR}/build.sql
DEPLOY=../db/db.sql
FUNCTIONS=$(shell ls scripts/functions/*.sql)
INIT=${CURDIR}/scripts/init.sql
TESTS=$(shell ls test/*.sql)
TEST=${CURDIR}/test.sql

IMAGE=robconery/velzypg

all: init build

install: all
	psql $(DB) < $(BUILD) --quiet

init:
	@cat $(INIT) >> $(BUILD)

functions:
	@cat $(FUNCTIONS) >> $(BUILD)

test: clean install
	psql $(DB) < test_data.sql

build: functions
	cp $(BUILD) ../$(CURRDIR)/cli/db.sql

image:
	docker build -t $(IMAGE) .

push:
	docker push $(IMAGE)

clean:
	@rm -rf $(BUILD)

.PHONY: test
