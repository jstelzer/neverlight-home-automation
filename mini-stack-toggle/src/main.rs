use std::process::{Command, Stdio};
use tray_item::{IconSource, TrayItem};
use std::env;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    gtk::init()?;

    let mut tray = TrayItem::new(
        "Ollama stack controller",
        IconSource::Resource("utilities-system-monitor"),
    )?;

    tray.add_menu_item("Status", || {
        println!("Get Status");
        match get_status() {
            Ok(output) => println!("{}", output),
            Err(e) => eprintln!("Failed to get status: {}", e),
        }
    })?;

    tray.add_menu_item("Toggle on/off", || {
        println!("Stop/Start");
        match toggle_stack() {
            Ok(_) => println!("Stack toggled successfully"),
            Err(e) => eprintln!("Failed to toggle stack: {}", e),
        }
    })?;

    tray.add_menu_item("Quit", || {
        gtk::main_quit();
    })?;

    gtk::main();
    Ok(())
}

fn get_status() -> Result<String, Box<dyn std::error::Error>> {
    let home = env::var("HOME")?;
    let output = Command::new("bash")
        .arg(format!("{}/projects/neverlight-home-automation/scripts/check_docker.sh", home))
        .stdout(Stdio::piped())
        .output()?;
    
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).into_owned())
    } else {
        let err = std::io::Error::new(std::io::ErrorKind::Other, "Command failed");
        Err(Box::new(err))
    }
}

fn toggle_stack() -> Result<(), Box<dyn std::error::Error>> {
    let home = env::var("HOME")?;
    let output = Command::new("bash")
        .arg(format!("{}/projects/neverlight-home-automation/scripts/control_docker.sh", home))
        .stdout(Stdio::piped())
        .output()?;
    
    if output.status.success() {
        Ok(())
    } else {
        let err = std::io::Error::new(std::io::ErrorKind::Other, "Command failed");
        Err(Box::new(err))
    }
}
