use super::system;
use system::dmesg;

// Signal to Nitro hypervisor that booting was successful
fn nitro_heartbeat() {
    use system::socket_connect;
    use libc::{write, read, close, AF_VSOCK};
    let mut buf: [u8; 1] = [0; 1];
    buf[0] = 0xB7; // AWS Nitro heartbeat value
    let fd = match socket_connect(AF_VSOCK, 9000, 3) {
        Ok(f)=> f,
        Err(e)=> {
            eprintln!("{}", e);
            return
        },
    };
    unsafe {
        write(fd, buf.as_ptr() as _, 1);
        read(fd, buf.as_ptr() as _, 1);
        close(fd);
    }
    dmesg(format!("Sent NSM heartbeat"));
}

// Initialize nitro device
pub fn init_platform(){
    use system::insmod;
    // TODO: error handling
    nitro_heartbeat();

	match insmod("/nsm.ko") {
        Ok(())=> dmesg(format!("Loaded nsm.ko")),
        Err(e)=> eprintln!("{}", e)
    };
}
