module extrapanel.tray;

import gtk.Menu;
import gtk.MenuItem;
import gtk.StatusIcon;

import gtk.c.types;

import gio.Application;
import gtk.Main;

import std.process;
import std.functional;

private StatusIcon trayIcon;

TrayApp app;

void main(string[] args) {
	Main.init(args);
	app = new TrayApp();
	app.run(args);
}

public void createPopupMenu(uint button, uint timestamp, StatusIcon icon) {
	Menu menu = createTrayMenu();
	menu.popupAtPointer(null);
}

public Menu createTrayMenu() {
	Menu menu = new Menu();

	MenuItem item = new MenuItem("Open config panel");
	item.addOnActivate(toDelegate(&openMainPanel));
	menu.append(item);

	item = new MenuItem("Exit");
	item.addOnActivate(toDelegate(&exit));
	menu.append(item);
	menu.showAll();
	return menu;
}

public void openMainPanel(MenuItem mi) {
	spawnProcess("extrapanel");
}

public void exit(MenuItem mi) {
	app.release();
}

private class TrayApp : Application {
public:
	this() {
		ApplicationFlags flags = ApplicationFlags.FLAGS_NONE;
		super("org.aurorafoss.extrapanel.tray", flags);
		this.addOnActivate(&onActivate);
		//initElements();
	}

private:
	void onActivate(Application app) {
		initElements();
		hold();
	}

	void initElements() {
		trayIcon = new StatusIcon("input-mouse");
		trayIcon.setTooltipText("Extra Panel is running...");
		trayIcon.addOnPopupMenu(toDelegate(&createPopupMenu));
	}
}