use std::process::Command;
use {tray_item::IconSource, tray_item::TrayItem};

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
        Command::new("bash")
            .arg("/home/mental/projects/neverlight-home-automation/scripts/check_docker.sh")
            .output()
            .expect("Unable to run command");
    })
    .unwrap();

    tray.add_menu_item("Toggle on/off", || {
        println!("Stop/Start");
        Command::new("bash")
            .arg("/home/mental/projects/neverlight-home-automation/scripts/control_docker.sh")
            .output()
            .expect("Unable to control docker");
    })
    .unwrap();

    tray.add_menu_item("Quit", || {
        gtk::main_quit();
    })
    .unwrap();

    gtk::main();
}
