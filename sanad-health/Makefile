.PHONY: test clean

EMACS ?= emacs
BATCH = $(EMACS) -Q -batch -L . -L tests -l tests/test-helper.el

test:
	$(BATCH) \
		-l tests/test-sanad-health.el \
		-l tests/test-sanad-health-setup.el \
		-l tests/test-sanad-health-agenda.el \
		-l tests/test-sanad-health-meds.el \
		-l tests/test-sanad-health-capture.el \
		-l tests/test-sanad-health-pomodoro.el \
		-l tests/test-sanad-health-log.el \
		-l tests/test-sanad-health-tracker.el \
		-f ert-run-tests-batch-and-exit

test-%:
	$(BATCH) -l tests/test-sanad-health-$*.el -f ert-run-tests-batch-and-exit

clean:
	rm -f *.elc tests/*.elc
