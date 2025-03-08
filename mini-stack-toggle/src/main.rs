use std::process::{Command, Stdio};
use tray_item::{IconSource, TrayItem};

fn main() {
    gtk::init().unwrap();

    let mut tray = TrayItem::new(
        "Tray Example",
        IconSource::Resource("utilities-system-monitor"),
    )
    .unwrap();

    tray.add_label("Ollama stack controller").unwrap();

    tray.add_menu_item("Status", || {
        println!("Get Status");
        match get_status() {
            Ok(output) => println!("{}", output),
            Err(e) => eprintln!("Failed to get status: {}", e),
        }
    })
    .unwrap();

    tray.add_menu_item("Toggle on/off", || {
        println!("Stop/Start");
        match toggle_stack() {
            Ok(_) => println!("Stack toggled successfully"),
            Err(e) => eprintln!("Failed to toggle stack: {}", e),
        }
    })
    .unwrap();

    tray.add_menu_item("Quit", || {
        gtk::main_quit();
    })
    .unwrap();

    gtk::main();
}

fn get_status() -> Result<String, std::io::Error> {
    let output = Command::new("bash")
        .arg("/home/mental/projects/neverlight-home-automation/scripts/check_docker.sh")
        .stdout(Stdio::piped())
        .output()?;
    
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).into_owned())
    } else {
        Err(std::io::Error::new(
            std::io::ErrorKind::Other,
            "Command failed",
        ))
    }
}

fn toggle_stack() -> Result<(), std::io::Error> {
    let output = Command::new("bash")
        .arg("/home/mental/projects/neverlight-home-automation/scripts/control_docker.sh")
        .stdout(Stdio::piped())
        .output()?;
    
    if output.status.success() {
        Ok(())
    } else {
        Err(std::io::Error::new(
            std::io::ErrorKind::Other,
            "Command failed",
        ))
    }
}
