REGISTRY := local
.DEFAULT_GOAL :=
.PHONY: default
default: out/nitro.eif

out:
	mkdir out

out/nitro.eif: out \
	$(shell git ls-files \
		src/init \
		src/aws \
	)
	docker build \
		--tag $(REGISTRY)/enclaveos \
		--progress=plain \
		--no-cache \
		--output type=local,rewrite-timestamp=true,dest=out\
		-f Containerfile \
		src/

.PHONY: run
run: out/nitro.eif
	sudo nitro-cli \
		run-enclave \
		--cpu-count 2 \
		--memory 512M \
		--eif-path out/nitro.eif \
		--debug-mode \
		--attach-console
