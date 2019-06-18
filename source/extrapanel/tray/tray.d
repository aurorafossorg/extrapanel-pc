module extrapanel.tray.tray;

import gtk.Menu;
import gtk.MenuItem;
import gtk.StatusIcon;

import gtk.c.types;

import gio.Application;
import gtk.Main;

import std.process;
import std.functional;

/**
 *	tray.d - Tray icon for the application
 */

private StatusIcon trayIcon;

TrayApp app;

void main(string[] args) {
	Main.init(args);
	app = new TrayApp();
	app.run(args);
}

private class TrayApp : Application {
public:
	this() {
		ApplicationFlags flags = ApplicationFlags.FLAGS_NONE;
		super("org.aurorafoss.extrapanel.tray", flags);
		this.addOnActivate(&onActivate);
	}

private:
	void onActivate(Application app) {
		if(!app.getIsRemote() && trayIcon is null) {
			initElements();
			hold();
		} else {
			return;
		}
	}

	void initElements() {
		trayIcon = new StatusIcon("input-mouse");
		trayIcon.setTooltipText("Extra Panel is running...");
		trayIcon.addOnPopupMenu(toDelegate(&createPopupMenu));
		trayIcon.addOnActivate(toDelegate(&openMainAppStatusIcon));
	}
}

// Creates the popup menu
public void createPopupMenu(uint button, uint timestamp, StatusIcon icon) {
	Menu menu = createTrayMenu();
	menu.popupAtPointer(null);
}

// Creates the tray menu
public Menu createTrayMenu() {
	Menu menu = new Menu();

	MenuItem item = new MenuItem("Open config panel");
	item.addOnActivate(toDelegate(&openMainAppMenuItem));
	menu.append(item);

	item = new MenuItem("Exit");
	item.addOnActivate(toDelegate(&exit));
	menu.append(item);
	menu.showAll();
	return menu;
}

// Opens the main app
public void openMainAppStatusIcon(StatusIcon si) {
	spawnProcess("extrapanel");
}

public void openMainAppMenuItem(MenuItem mi) {
	spawnProcess("extrapanel");
}

// Exits the tray app
public void exit(MenuItem mi) {
	app.release();
}