module extrapanel.tray.main;

// GTK
import gtk.Main;
import gtk.Menu;
import gtk.MenuItem;
import gtk.StatusIcon;

// GIO
import gio.Application;

// STD
import std.functional;
import std.process;

/**
 *	tray.d - Tray icon for the application
 */

private StatusIcon trayIcon;

/// The main app for the tray icon.
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

/// Creates the popup menu
public void createPopupMenu(uint, uint, StatusIcon) {
	Menu menu = createTrayMenu();
	menu.popupAtPointer(null);
}

/// Creates the tray menu
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

/// Callback to open the main app from the icon
public void openMainAppStatusIcon(StatusIcon) {
	spawnProcess("extrapanel");
}

/// Callback to open the main app from the menu option
public void openMainAppMenuItem(MenuItem) {
	spawnProcess("extrapanel");
}

// /// Callback to close the tray
public void exit(MenuItem) {
	app.release();
}