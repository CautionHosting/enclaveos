# stagex release: 2025.07.0

FROM stagex/core-binutils@sha256:f989b48a168f38563b74718b0568118f6a4107916b22bd2457c974ca5bf4c7f4 AS core-binutils
FROM stagex/core-ca-certificates@sha256:92400d9ed9ee1cf3c7568b3bdaa6c2c1aac3cabff4060dab99d1a8359e782e5a AS core-ca-certificates
FROM stagex/core-gcc@sha256:ea69941739b0aa5bfb6b1dff8bb4bd7f5117f9cc26e3d9d1f830f35b2fc04c5c AS core-gcc
FROM stagex/core-zlib@sha256:a143ed84d0aef7012d556df95904017e442c221117a07e5affc395440a2dae88 AS core-zlib
FROM stagex/core-llvm@sha256:c74f00501fa8dcb2bd319f493fcac3364d7ccbc29051516d653d019eac116151 AS core-llvm
FROM stagex/core-openssl@sha256:65bf9dc8676437ebc279f516c8d696936d620f3f53c81c2a35bd05e1360c6d99 AS core-openssl
FROM stagex/user-eif_build@sha256:0eabf3d09ccf0421bc09fe9e90b656ecc1140155d5358f35de63e2cfd814f4f9 AS user-eif_build
FROM stagex/user-gen_initramfs@sha256:aff0791ee9ccdeed1304b5bb4edb7fc5b7f485e11bccf5e61668001243ada815 AS user-gen_initramfs
FROM stagex/core-libunwind@sha256:cd88506914270f72ec82398390cb8e4c9cfb8173afbc4ad570bf319ee870400b AS core-libunwind
FROM stagex/core-rust@sha256:16024267454141decbe82569731aa6e2a9be64411659e828c0988243ababf914 AS core-rust
FROM stagex/core-musl@sha256:79400dfed7fd30ff939bbd5b1fb2cb114910865891d1bd75e2067a394c3fb4f1 AS core-musl
FROM stagex/core-git@sha256:7ab36d6183162f0397eba3d5603beceb455982a1f2c122740484af0eb2497444 AS core-git
FROM stagex/core-pkgconf@sha256:608b378949cedc86df6350e5ec428b0e114bb7bc46bc33330b51215cc8ac4a68 AS core-pkgconf
FROM stagex/core-busybox@sha256:17e496211470fbd77057692619295e32c841e90312e48bce56a171fdb041b0c9 AS core-busybox
FROM stagex/user-linux-nitro@sha256:655924404a008c6c70c3411e7b32d6558ac388bcc3a5a02431029e63c93d1985 AS user-linux-nitro
FROM stagex/user-cpio@sha256:05701450a186fa1cb5a8287f7fa4d216e610a15d22c2e3e86d70ac3550d9cd3c AS user-cpio

FROM scratch as base

COPY --from=core-busybox . /
COPY --from=core-musl . /
COPY --from=core-libunwind . /
COPY --from=core-openssl . /
COPY --from=core-zlib . /
COPY --from=core-ca-certificates . /
COPY --from=core-binutils . /
COPY --from=core-pkgconf . /
COPY --from=core-git . /
COPY --from=core-rust . /
COPY --from=user-gen_initramfs . /
COPY --from=user-eif_build . /
COPY --from=core-llvm . /
COPY --from=core-gcc . /
COPY --from=user-linux-nitro /bzImage .
COPY --from=user-linux-nitro /linux.config .
COPY --from=user-cpio . /
ADD . /src

FROM base as build
WORKDIR /build_cpio
COPY --from=local/nit /usr/bin/init /build_cpio/rootfs/init
ENV KBUILD_BUILD_TIMESTAMP=1
RUN <<-EOF
	# NOTE: Relative directory is important!
	( \
		cd /build_cpio/rootfs; \
		find . -exec touch -hcd "@0" "{}" + -print0 \
			| sort -z \
			| cpio --null --create --verbose --reproducible --format=newc \
			| gzip --best \
			> ../rootfs.cpio \
	)
	# gen_init_cpio -t 1 initramfs.list > rootfs.cpio
	touch -hcd "@0" rootfs.cpio
EOF
WORKDIR /build_eif
RUN eif_build \
	--kernel /bzImage \
	--kernel_config /linux.config \
	--ramdisk /build_cpio/rootfs.cpio \
	--pcrs_output /nitro.pcrs \
	--output /nitro.eif \
	--cmdline 'reboot=k initrd=0x2000000,3228672 root=/dev/ram0 panic=1 pci=off nomodules console=ttyS0 i8042.noaux i8042.nomux i8042.nopnp i8042.dumbkbd'

FROM base as install
WORKDIR /rootfs
COPY --from=build /nitro.eif .
COPY --from=build /nitro.pcrs .

FROM scratch as package
COPY --from=install /rootfs .
