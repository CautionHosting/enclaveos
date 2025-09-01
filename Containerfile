FROM stagex/core-binutils@sha256:f2d3bf6104db0d5ac39ca155c0241bfea2516a6829e3b4fd657cf9ba5b625478 AS core-binutils
FROM stagex/core-ca-certificates@sha256:d135f1189e9b232eb7316626bf7858534c5540b2fc53dced80a4c9a95f26493e AS core-ca-certificates
FROM stagex/core-gcc@sha256:964ffd3793c5a38ca581e9faefd19918c259f1611c4cbf5dc8be612e3a8b72f5 AS core-gcc
FROM stagex/core-zlib@sha256:06f5168e20d85d1eb1d19836cdf96addc069769b40f8f0f4a7a70b2f49fc18f8 AS core-zlib
FROM stagex/core-llvm@sha256:583ecda677f51b69857f8027dfc58f4a931d1adc4d16214870a373505210d973 AS core-llvm
FROM stagex/core-openssl@sha256:d6487f0cb15f4ee02b420c717cb9abd85d73043c0bb3a2c6ce07688b23c1df07 AS core-openssl
FROM stagex/user-eif_build@sha256:935032172a23772ea1a35c6334aa98aa7b0c46f9e34a040347c7b2a73496ef8a AS user-eif_build
FROM stagex/user-gen_initramfs@sha256:a87e9a3fa8468d2e08b5abb0a6da4c7a11df22273e2c526cb22e6b131151def8 AS user-gen_initramfs
FROM stagex/core-libunwind@sha256:eb66122d8fc543f5e2f335bb1616f8c3a471604383e2c0a9df4a8e278505d3bc AS core-libunwind
FROM stagex/core-rust@sha256:2ea0be043b92321b5d1c2784911a770ccca28c09c3cf6a0f81fc0cd05a2abb08 AS core-rust
FROM stagex/core-musl@sha256:d9af23284cca2e1002cd53159ada469dfe6d6791814e72d6163c7de18d4ae701 AS core-musl
FROM stagex/core-git@sha256:6b3e0055f6aeaa8465f207a871db2c63a939cd7406113e9d769ff3b37239f3d0 AS core-git
FROM stagex/core-pkgconf@sha256:52624a89bb8cc684bc0391fcb7770ded2bbcb281e84bdb68a31fce127439fd7b AS core-pkgconf
FROM stagex/core-busybox@sha256:637b1e0d9866807fac94c22d6dc4b2e1f45c8a5ca1113c88172e0324a30c7283 AS core-busybox
FROM stagex/user-linux-nitro@sha256:aa1006d91a7265b33b86160031daad2fdf54ec2663ed5ccbd312567cc9beff2c AS user-linux-nitro

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
