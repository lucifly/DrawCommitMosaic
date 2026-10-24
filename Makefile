SHELL := /bin/bash
SHELLCHECK ?= shellcheck
SHFMT ?= shfmt
SHELL_FILES := drawHeart.sh shellpullpush.sh scripts/draw-commits.sh tests/test_draw_commits.sh

.PHONY: check lint format test

check: lint test

lint:
	$(SHELLCHECK) --severity=style $(SHELL_FILES)
	$(SHFMT) -d -i 2 -ci -sr $(SHELL_FILES)
	@for file in $(SHELL_FILES); do bash -n "$$file" || exit; done

format:
	$(SHFMT) -w -i 2 -ci -sr $(SHELL_FILES)

test:
	bash tests/test_draw_commits.sh
