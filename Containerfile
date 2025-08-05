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

FROM scratch as base
ENV TARGET=x86_64-unknown-linux-musl
ENV RUSTFLAGS="-C target-feature=+crt-static"
ENV CARGOFLAGS="--locked --no-default-features --release --target ${TARGET}"
ENV OPENSSL_STATIC=true

COPY --from=busybox . /
COPY --from=musl . /
COPY --from=libunwind . /
COPY --from=openssl . /
COPY --from=zlib . /
COPY --from=ca-certificates . /
COPY --from=binutils . /
COPY --from=pkgconf . /
COPY --from=git . /
COPY --from=rust . /
COPY --from=gen_initramfs . /
COPY --from=eif_build . /
COPY --from=llvm . /
COPY --from=gcc . /
COPY --from=linux-nitro /bzImage .
COPY --from=linux-nitro /nsm.ko .
COPY --from=linux-nitro /linux.config .
ADD . /src

FROM base as build
WORKDIR /src/init
RUN cargo build ${CARGOFLAGS}
WORKDIR /build_cpio
RUN cp /src/init/target/${TARGET}/release/init init
ENV KBUILD_BUILD_TIMESTAMP=1
COPY <<-EOF initramfs.list
	file /init     init    0755 0 0
	file /nsm.ko   /nsm.ko 0755 0 0
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
	--cmdline 'reboot=k initrd=0x2000000,3228672 root=/dev/ram0 panic=1 pci=off nomodules console=ttyS0 i8042.noaux i8042.nomux i8042.nopnp i8042.dumbkbd'

FROM base as install
WORKDIR /rootfs
COPY --from=build /nitro.eif .
COPY --from=build /nitro.pcrs .

FROM scratch as package
COPY --from=install /rootfs .
