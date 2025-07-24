FROM stagex/core-binutils:sx2025.06.1@sha256:f989b48a168f38563b74718b0568118f6a4107916b22bd2457c974ca5bf4c7f4 AS core-binutils
FROM stagex/core-ca-certificates:sx2025.06.1@sha256:4d76a4864f241727b2ba20bd7dc9fe32ce049bb9a056e75c51f851187974e399 AS core-ca-certificates
FROM stagex/core-gcc:sx2025.06.1@sha256:ea69941739b0aa5bfb6b1dff8bb4bd7f5117f9cc26e3d9d1f830f35b2fc04c5c AS core-gcc
FROM stagex/core-zlib:sx2025.06.1@sha256:a143ed84d0aef7012d556df95904017e442c221117a07e5affc395440a2dae88 AS core-zlib
FROM stagex/core-llvm:sx2025.06.1@sha256:b836e00c49b752ceb324a018a8436d40b265ffe1f4e9e852751081add5ed4940 AS core-llvm
FROM stagex/core-openssl:sx2025.06.1@sha256:65bf9dc8676437ebc279f516c8d696936d620f3f53c81c2a35bd05e1360c6d99 AS core-openssl
FROM stagex/user-eif_build:sx2025.06.1@sha256:70c62f75d64cce6aa5d983057c591a798f82944156ed613c1172c3b7ef7aa31e AS user-eif_build
FROM stagex/user-gen_initramfs:sx2025.06.1@sha256:aff0791ee9ccdeed1304b5bb4edb7fc5b7f485e11bccf5e61668001243ada815 AS user-gen_initramfs
FROM stagex/core-libunwind:sx2025.06.1@sha256:cd88506914270f72ec82398390cb8e4c9cfb8173afbc4ad570bf319ee870400b AS core-libunwind
FROM stagex/core-rust:sx2025.06.1@sha256:4fd4c70535a4b951e08e7b50e2bf625320928c08cf83c37f57eb3fbcb204cfcd AS core-rust
FROM stagex/core-libzstd:sx2025.06.1@sha256:35ae8f0433cf1472f8fb25e74dc631723e9f458ca3e9544976beb724690adea8 AS core-libzstd
FROM stagex/core-musl:sx2025.06.1@sha256:79400dfed7fd30ff939bbd5b1fb2cb114910865891d1bd75e2067a394c3fb4f1 AS core-musl
FROM stagex/core-git:sx2025.06.1@sha256:1504bfc60913bbb1fac41488cc16188fce46e038f5ec5cc9e295e6f4984cab44 AS core-git
FROM stagex/core-pkgconf:sx2025.06.1@sha256:608b378949cedc86df6350e5ec428b0e114bb7bc46bc33330b51215cc8ac4a68 AS core-pkgconf
FROM stagex/core-busybox:sx2025.06.1@sha256:17e496211470fbd77057692619295e32c841e90312e48bce56a171fdb041b0c9 AS core-busybox
FROM stagex/user-linux-nitro:sx2025.06.1@sha256:655924404a008c6c70c3411e7b32d6558ac388bcc3a5a02431029e63c93d1985 AS user-linux-nitro

FROM scratch AS base
ENV TARGET=x86_64-unknown-linux-musl
ENV RUSTFLAGS="-C target-feature=+crt-static"
ENV CARGOFLAGS="--locked --no-default-features --release --target ${TARGET}"
ENV OPENSSL_STATIC=true

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
COPY --from=core-libzstd . /
COPY --from=user-gen_initramfs . /
COPY --from=user-eif_build . /
COPY --from=core-llvm . /
COPY --from=core-gcc . /
COPY --from=user-linux-nitro /bzImage .
COPY --from=user-linux-nitro /linux.config .
ADD . /src

FROM base AS build
WORKDIR /src/init
RUN cargo build ${CARGOFLAGS}
WORKDIR /build_cpio
RUN cp /src/init/target/${TARGET}/release/init init
ENV KBUILD_BUILD_TIMESTAMP=1
COPY <<-EOF initramfs.list
	file /init     init    0755 0 0
	dir  /run              0755 0 0
	dir  /tmp              0755 0 0
	dir  /etc              0755 0 0
	dir  /bin              0755 0 0
	dir  /sbin             0755 0 0
	dir  /proc             0755 0 0
	dir  /sys              0755 0 0
	dir  /usr              0755 0 0
	dir  /usr/bin          0755 0 0
	dir  /usr/sbin         0755 0 0
	dir  /dev              0755 0 0
	dir  /dev/shm          0755 0 0
	dir  /dev/pts          0755 0 0
	nod  /dev/console      0600 0 0 c 5 1
EOF
RUN <<-EOF
	find . -exec touch -hcd "@0" "{}" +
	gen_init_cpio -t 1 initramfs.list > rootfs.cpio
	touch -hcd "@0" rootfs.cpio
EOF
WORKDIR /build_eif
RUN eif_build \
	--kernel /bzImage \
	--kernel_config /linux.config \
	--ramdisk /build_cpio/rootfs.cpio \
	--pcrs_output /nitro.pcrs \
	--output /nitro.eif \
	--cmdline 'reboot=k initrd=0x2000000,3228672 root=/dev/ram0 panic=1 pci=off nomodules console=ttyS0 earlyprintk=ttyS0 debug i8042.noaux i8042.nomux i8042.nopnp i8042.dumbkbd dyndbg="file nsm.c +p"'

FROM base AS install
WORKDIR /rootfs
COPY --from=build /nitro.eif .
COPY --from=build /nitro.pcrs .

FROM scratch AS package
COPY --from=install /rootfs .