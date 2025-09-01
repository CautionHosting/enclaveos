REGISTRY := local
.DEFAULT_GOAL :=
.PHONY: default
default: out/nitro.eif

out:
	mkdir out

out/nitro.eif: out
	docker build \
		--tag $(REGISTRY)/enclaveos \
		--progress=plain \
		--output type=local,rewrite-timestamp=true,dest=out\
		-f Containerfile \
		.

.PHONY: run
run: out/nitro.eif
	sudo nitro-cli \
		run-enclave \
		--cpu-count 2 \
		--memory 512M \
		--eif-path out/nitro.eif \
		--debug-mode \
		--attach-console
