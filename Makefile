.PHONY: test integration smoke fmt check

# plenary busted, one headless nvim per spec file.
test:
	nvim --headless -u tests/minimal_init.lua \
	  -c "PlenaryBustedDirectory tests/spec { minimal_init = 'tests/minimal_init.lua', sequential = true }"

# Real keys into real floats, one headless nvim per file. Writes nothing.
integration:
	nvim --headless -u tests/minimal_init.lua \
	  -c "PlenaryBustedDirectory tests/integration { minimal_init = 'tests/minimal_init.lua', sequential = true }"

smoke:
	@for t in tests/smoke/*.sh; do [ -e "$$t" ] || continue; echo "== $$t"; bash "$$t" || exit 1; done

fmt:
	stylua .

check:
	stylua --check .
