# EnclaveOS #

<https://git.distrust.co/public/enclaveos>

## About ##

A minimal, immutable, and deterministic Linux unikernel build system targeting
various Trusted Execution Environments for use cases that require high security
and accountability.

This is intended as a reference repository which could serve as a boilerplate
to build your own hardened and immutable operating system images for high
security applications.

## Architecture ##

```mermaid
---
config:
  theme: base
---
C4Context
    title System Context diagram for Internet Banking System
    Boundary(enclaveos, "EnclaveOS") {
        System(kernel1,"Offline Kernel")
        System(nit,"Init System","nit")
        System(serviced,"Service Manager","serviced")
        System(guestctl,"Guest Management","guestctl")
        BiRel(guestctl,gateway-kernel,"vsock")
        BiRel(guestctl,enclave-kernel,"vsock")
        BiRel(guestctl,bootproof-agent,"vsock") 
        System(bootproof-agent,"Attestation Agent","bootproof-agent")
        Boundary(iommu, "IOMMU") {
            Boundary(enclave-vm, "Enclave VM") {
                System(enclave-kernel,"Offline Kernel")
                System(user-service,"User Provided Service")
                System(keyforkd,"Keyfork Daemon")
            }
            Boundary(gateway-vm", "Gateway VM") {
                System(gateway-kernel,"Online Kernel")
                System(enclaved,"EnclaveOS API")
                System(bootproofd,"Bootproof API")
            }
        }
        Boundary(b1,"Hardware") {   
            System(attest1,"TEE/HSM","TPM2, Nitro, TDX, SEV")
            System(nic1, "NIC", "")
            System(disk1,"Disk","")
        }
    }
    Person(user1, "Client", "End User")
    System(endorsement-api,"Platform Endorsement API","AWS,GCP,Azure")
    Rel(endorsement-api,gateway-kernel,"")
    Rel(kernel1,nit,"")
    Rel(nit,serviced,"")
    Rel(serviced,guestctl,"")
    BiRel(attest1,bootproof-agent,"")
    Rel(nic1,gateway-kernel,"iommu")
    Rel(disk1,enclave-kernel,"iommu")
    BiRel(user-service,enclave-kernel,"")
    BiRel(keyforkd,user-service,"")
    BiRel(keyforkd,enclave-kernel,"")
    BiRel(user1,gateway-kernel,"vsock")
    BiRel(gateway-kernel,bootproofd,"")
    BiRel(gateway-kernel,enclaved,"")
```

## Platforms ##

| Platform                   | Target  | Status   | Verified boot Method  |
|----------------------------|:-------:|:--------:|:---------------------:|
| AWS Nitro Enclaves         | aws     | booting  | Nitro attestation API |
| GCP Confidential Compute   | gcp     | research | vTPM 2.0 attestation  |
| Azure Confidential VMs     | azure   | research | vTPM 2.0 attestation  |
| Generic/Qemu               | generic | research | vTPM 2.0 attestation  |

## Features ##

 * Immutability
   * Root filesystem is a CPIO filesystem extracted to a RamFS at boot
 * Minimalism
   * < 5MB footprint
   * Nothing is included but a kernel and your target binary by default
   * Sample "hello world" included as a default reference
   * Debug builds include busybox init shim and drop to a shell
 * Determinism
   * Multiple people can build artifacts and get identical hashes
   * Allows one to prove distributed artifacts correspond to published sources
 * Hardening
   * No TCP/IP network support
     * Favor using a virtual socket or physical interface to a gateway system
   * Most unessesary kernel features are disabled at compile time
   * Follow [Kernel Self Protection Project](kspp) recommendations

[  kspp]: https://kernsec.org/wiki/index.php/Kernel_Self_Protection_Project

## Development ##

### Requirements ###

 * 10GB+ free RAM
 * Docker 20+
 * GNU Make

### Build
```
make
