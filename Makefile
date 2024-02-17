REGISTRY := local
.DEFAULT_GOAL :=
.PHONY: default
default: out/enclaveos.tar

out:
	mkdir out

out/enclaveos.tar: out \
	$(shell git ls-files \
		src/init \
		src/aws \
	)
	docker build \
		--tag $(REGISTRY)/enclaveos \
		--progress=plain \
		--output "\
			type=oci,\
			rewrite-timestamp=true,\
			force-compression=true,\
			name=enclaveos,\
			dest=$@" \
		-f Containerfile \
		src/
