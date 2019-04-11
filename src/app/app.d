module extrapanel.app;

import util.config;
import util.logger;
import util.paths;

import plugin.plugin;
import plugin.browser;

// STD
import std.stdio;
import std.file;
import std.conv;

import core.thread;

// GTK
// Types
import gtk.c.types;

// Top level
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Widget;
import gtk.Window;

import glib.Timeout;

import pango.PgAttributeList;
import pango.PgAttribute;

// Contruct
import gtk.Builder;

// Elements
import gtk.Button;
import gtk.Label;
import gtk.Stack;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.Box;
import gtk.Notebook;
import gtk.ScrolledWindow;
import gtk.CheckButton;
import gtk.ToggleButton;
import gtk.StatusIcon;
import gtk.Menu;
import gtk.SpinButton;
import gtk.TreeView;

// Top level
import gio.Application : GApplication = Application;

// Elements
import gio.Menu : GMenu = Menu;
import gio.MenuItem : GMenuItem = MenuItem;

// GDK
import gdkpixbuf.Pixbuf;
import gdkpixbuf.PixbufLoader;

/**
 *	app.d - Main UI manager for the app
 */

// TODO - Dirty debug code, refactor with development of communication
enum State {
	Online,
	Offline,
	Disabled
}

static State wifiState = State.Disabled, bluetoothState = State.Disabled, usbState = State.Disabled;
Timeout timeout;

static bool currentStatus = false;

/// Main application
class ExtraPanelGUI : Application
{
public:
	/// Constructor
	this()
	{
		// Loads configuration and sets callbacks
		Configuration.load();
		ApplicationFlags flags = ApplicationFlags.FLAGS_NONE;
		super("org.aurorafoss.extrapanel", flags);
		this.window = null;
		this.addOnActivate(&onAppActivate);
		this.addOnShutdown(&onAppDestroy);

		timeout = new Timeout(100, &updateDaemonStatus);
	}

private:
	// App activated
	void onAppActivate(GApplication app) {
		logger.trace("Activate App Signal");
		// Detect if there are other instances of this app running
		if (!app.getIsRemote() && window is null)
		{
			// Loads the UI files
			logger.trace("Primary instance, loading UI...");
			builder = new Builder();
			if(!builder.addFromResource("/org/aurorafoss/extrapanel/ui/window.ui"))
			{
				logger.critical("Window resource cannot be found");
				return;
			}

			// Setup the app
			initElements();
			updateElements();
		} else {
			logger.trace("Another instance exists, taking control...");
		}

		// Show
		this.window.present();
	}

	void onAppDestroy(GApplication app) {
		// Saves Configs
		Configuration.save();
	}

	// Constructor
	Builder builder;

	// Window
	ApplicationWindow window;

	// Meta Elements
	Button backButton, startButton, stopButton;
	Label status;

	// Sidebar
	Stack sidebar;
		ListBox generalBar;
			ListBoxRow gPluginsOption;
			ListBoxRow gConfigOption;
			ListBoxRow gAboutOption;
		ListBox pluginsBar;
			ListBoxRow pPluginsOption;
			ListBoxRow pPacksOption;
			ListBoxRow pInstalledOption;
		ListBox configBar;
			ListBoxRow cGeneralOption;
			ListBoxRow cConnectionOption;
			ListBoxRow cPluginsOption;
			ListBoxRow cDevicesOption;

	// Main Interface
	Stack mainInterface;
		Box generalInterface;
			Button wifiButton, bluetoothButton, usbButton;
			Label uuidLabel;
		Stack pluginsInterface;
			Stack pPluginsInterface;
				TreeView pPluginsTreeView;
			Stack pPacksInterface;
				TreeView pPacksTreeView;
			Stack pInstalledInterface;
				TreeView pInstalledTreeView;
		Stack configInterface;
			ScrolledWindow cGeneralInterface;
				CheckButton cgOpenAppStartup;
				SpinButton cgCommDelay;
			Notebook cConnectionInterface;
				Box ccWifiInterface;
					CheckButton ccwEnableCheck;
				Box ccBluetoothInterface;
					CheckButton ccbEnableCheck;
				Box ccUsbInterface;
					CheckButton ccuEnableCheck;
			ScrolledWindow cPluginsInterface;
				Box cpPanels;
			Box cDevicesInterface;


	// Inits the builder defined elements
	void initElements()
	{
		// Top level
		window = cast(ApplicationWindow) builder.getObject("window");
		window.setApplication(this);

		// Meta Elements
		backButton = cast(Button) builder.getObject("backButton");
		startButton = cast(Button) builder.getObject("startButton");
		stopButton = cast(Button) builder.getObject("stopButton");
		status = cast(Label) builder.getObject("status");

		// General Tab Elements
		wifiButton = cast(Button) builder.getObject("wifiButton");
		bluetoothButton = cast(Button) builder.getObject("bluetoothButton");
		usbButton = cast(Button) builder.getObject("usbButton");
		uuidLabel = cast(Label) builder.getObject("uuidLabel");

		// Sidebar
		sidebar = cast(Stack) builder.getObject("sidebar");
		generalBar = cast(ListBox) builder.getObject("generalBar");
		gPluginsOption = cast(ListBoxRow) builder.getObject("gPluginsOption");
		gConfigOption = cast(ListBoxRow) builder.getObject("gConfigOption");
		gAboutOption = cast(ListBoxRow) builder.getObject("gAboutOption");
		pluginsBar = cast(ListBox) builder.getObject("pluginsBar");
		pPluginsOption = cast(ListBoxRow) builder.getObject("pPluginsOption");
		pPacksOption = cast(ListBoxRow) builder.getObject("pPacksOption");
		pInstalledOption = cast(ListBoxRow) builder.getObject("pInstalledOption");
		configBar = cast(ListBox) builder.getObject("configBar");
		cGeneralOption = cast(ListBoxRow) builder.getObject("cGeneralOption");
		cConnectionOption = cast(ListBoxRow) builder.getObject("cConnectionOption");
		cPluginsOption = cast(ListBoxRow) builder.getObject("cPluginsOption");
		cDevicesOption = cast(ListBoxRow) builder.getObject("cDevicesOption");

		// Main Interface
		mainInterface = cast(Stack) builder.getObject("mainInterface");
		generalInterface = cast(Box) builder.getObject("generalInterface");
		pluginsInterface = cast(Stack) builder.getObject("pluginsInterface");
		pPluginsInterface = cast(Stack) builder.getObject("pPluginsInterface");
		pPluginsTreeView = cast(TreeView) builder.getObject("pPluginsTreeView");
		pPacksInterface = cast(Stack) builder.getObject("pPacksInterface");
		pPacksTreeView = cast(TreeView) builder.getObject("pPacksTreeView");
		pInstalledInterface = cast(Stack) builder.getObject("pInstalledInterface");
		pInstalledTreeView = cast(TreeView) builder.getObject("pInstalledTreeView");
		configInterface = cast(Stack) builder.getObject("configInterface");
		cGeneralInterface = cast(ScrolledWindow) builder.getObject("cGeneralInterface");
		cgOpenAppStartup = cast(CheckButton) builder.getObject("cgOpenAppStartup");
		cgCommDelay = cast(SpinButton) builder.getObject("cgCommDelay");
		cConnectionInterface = cast(Notebook) builder.getObject("cConnectionInterface");
		ccWifiInterface = cast(Box) builder.getObject("ccWifiInterface");
		ccwEnableCheck = cast(CheckButton) builder.getObject("ccwEnableCheck");
		ccBluetoothInterface = cast(Box) builder.getObject("ccBluetoothInterface");
		ccbEnableCheck = cast(CheckButton) builder.getObject("ccbEnableCheck");
		ccUsbInterface = cast(Box) builder.getObject("ccUsbInterface");
		ccuEnableCheck = cast(CheckButton) builder.getObject("ccuEnableCheck");
		cPluginsInterface = cast(ScrolledWindow) builder.getObject("cPluginsInterface");
		cpPanels = cast(Box) builder.getObject("cpPanels");
		cDevicesInterface = cast(Box) builder.getObject("cDevicesInterface");
	}

	void updateElements()
	{
		// Defines the communication statuses
		wifiState = Configuration.getOption!(bool)(Options.WiFiEnabled) ? State.Offline : State.Disabled;
		bluetoothState = Configuration.getOption!(bool)(Options.BluetoothEnabled) ? State.Offline : State.Disabled;
		usbState = Configuration.getOption!(bool)(Options.UsbEnabled) ? State.Offline : State.Disabled;

		// Config - Communication Checkboxes
		ccwEnableCheck.setActive(Configuration.getOption!(bool)(Options.WiFiEnabled));
		ccbEnableCheck.setActive(Configuration.getOption!(bool)(Options.BluetoothEnabled));
		ccuEnableCheck.setActive(Configuration.getOption!(bool)(Options.UsbEnabled));

		// UUID
		cgOpenAppStartup.setActive(Configuration.getOption!(bool)(Options.LoadOnBoot));
		uuidLabel.setLabel("UUID: " ~ Configuration.getOption!(string)(Options.DeviceUUID));

		// Update UI state for communication
		setConnectionButtonState(wifiButton, wifiState);
		setConnectionButtonState(bluetoothButton, bluetoothState);
		setConnectionButtonState(usbButton, usbState);

		// Callbacks
		generalBar.addOnRowActivated(&sidebarOnChange);
		pluginsBar.addOnRowActivated(&sidebarOnChange);
		configBar.addOnRowActivated(&sidebarOnChange);

		wifiButton.addOnClicked(&communicationButtonCallback);
		bluetoothButton.addOnClicked(&communicationButtonCallback);
		usbButton.addOnClicked(&communicationButtonCallback);

		cgOpenAppStartup.addOnToggled(&cgEnableBoxes);

		ccwEnableCheck.addOnToggled(&ccEnableBoxes);
		ccbEnableCheck.addOnToggled(&ccEnableBoxes);
		ccuEnableCheck.addOnToggled(&ccEnableBoxes);

		//cPluginsInterface.addOnMap(&cpLoadPlugins);
		cpLoadPlugins();

		backButton.addOnClicked(&backButtonCallback);

		// Queries the state of the daemon
		currentStatus = queryDaemon();
		updateMetaElements();
	}

	void setConnectionButtonState(Button button, State state) {
		string id;
		if(button == wifiButton)
			id = "wifiButton";
		else if(button == bluetoothButton)
			id = "bluetoothButton";
		else if(button == usbButton)
			id = "usbButton";

		switch(state) {
			case State.Online:
				button.setSensitive(true);
				Label label = cast(Label) builder.getObject(id ~ "Label");
				label.setLabel("Active");
				PgAttributeList attrs = label.getAttributes() is null ? new PgAttributeList() : label.getAttributes();
				attrs.change(PgAttribute.foregroundNew(0x4e4e, 0x9a9a, 0x0606));
				label.setAttributes(attrs);

				break;
			case State.Offline:
				button.setSensitive(true);
				Label label = cast(Label) builder.getObject(id ~ "Label");
				label.setLabel("Offline");
				PgAttributeList attrs = label.getAttributes() is null ? new PgAttributeList() : label.getAttributes();
				attrs.change(PgAttribute.foregroundNew(0xcccc, 0x0000, 0x0000));
				label.setAttributes(attrs);

				break;
			case State.Disabled:
				button.setSensitive(false);
				Label label = cast(Label) builder.getObject(id ~ "Label");
				label.setLabel("Disabled");
				label.setAttributes(new PgAttributeList());

				break;
			default:
				break;
		}
	}

	void communicationButtonCallback(Button b) {
		if(b == wifiButton) {
			wifiState = wifiState is State.Online ? State.Offline : State.Online;
			setConnectionButtonState(wifiButton, wifiState);
		} else if (b == bluetoothButton) {
			bluetoothState = bluetoothState is State.Online ? State.Offline : State.Online;
			setConnectionButtonState(bluetoothButton, bluetoothState);
		} else if (b == usbButton) {
			usbState = usbState is State.Online ? State.Offline : State.Online;
			setConnectionButtonState(usbButton, usbState);
		}
	}

	void sidebarOnChange(ListBoxRow lbr, ListBox lb) {
		logger.trace("sidebarOnChange()");
		backButton.setVisible(true);
		if(lb == generalBar) {
			if(lbr == gConfigOption) {
					sidebar.setVisibleChild(configBar);
					mainInterface.setVisibleChild(configInterface);
					configInterface.setVisibleChild(cGeneralInterface);
			} else if(lbr == gPluginsOption) {
					sidebar.setVisibleChild(pluginsBar);
					mainInterface.setVisibleChild(pluginsInterface);
			}
		} else if(lb == pluginsBar) {

		} else if(lb == configBar) {
			if(lbr == cGeneralOption) {
				configInterface.setVisibleChild(cGeneralInterface);
			} else if(lbr == cConnectionOption) {
				configInterface.setVisibleChild(cConnectionInterface);
			} else if(lbr == cPluginsOption) {
				configInterface.setVisibleChild(cPluginsInterface);
			} else if(lbr == cDevicesOption) {
				configInterface.setVisibleChild(cDevicesInterface);
			}
		}
	}

	void backButtonCallback(Button b) {
		logger.trace("backButtonCallback()");
		sidebar.setVisibleChild(generalBar);
		mainInterface.setVisibleChild(generalInterface);
		backButton.setVisible(false);
	}

	void cgEnableBoxes(ToggleButton tb) {
		Configuration.setOption(Options.LoadOnBoot, tb.getActive());
	}

	void ccEnableBoxes(ToggleButton tb) {
		State state = tb.getActive() ? State.Offline : State.Disabled;
		if(tb == ccwEnableCheck) {
			wifiState = state;
			Configuration.setOption(Options.WiFiEnabled, tb.getActive());
			setConnectionButtonState(wifiButton, wifiState);
		} else if(tb == ccbEnableCheck) {
			bluetoothState = state;
			Configuration.setOption(Options.BluetoothEnabled, tb.getActive());
			setConnectionButtonState(bluetoothButton, bluetoothState);
		} else if(tb == ccuEnableCheck) {
			usbState = state;
			Configuration.setOption(Options.UsbEnabled, tb.getActive());
			setConnectionButtonState(usbButton, usbState);
		}
	}

	bool updateDaemonStatus() {
		bool newStatus = queryDaemon();
		if(currentStatus != newStatus) {
			currentStatus = newStatus;
			updateMetaElements();
		}
		return true;
	}

	void updateMetaElements() {
		stopButton.setSensitive(currentStatus);
		startButton.setSensitive(!currentStatus);
		status.setLabel(currentStatus ? "Running" : "Stopped");
		
		PgAttributeList attrs = status.getAttributes() is null ? new PgAttributeList() : status.getAttributes();
		attrs.change(currentStatus ? PgAttribute.foregroundNew(0x4e4e, 0x9a9a, 0x0606) : PgAttribute.foregroundNew(0xc000, 0x0000, 0x0000));
		status.setAttributes(attrs);
	}

	bool queryDaemon() {
		return exists(appConfigPath ~ LOCK_PATH);
	}

	void cpLoadPlugins() {
		logger.trace("Showed up");

		string[] ids = getInstalledPlugins();

		// Empty the container
		//cpPanels.removeAll();
		foreach(id; ids) {
			parseInfo(new PluginInfo(id), Template.ConfigElement, cpPanels, builder, window);
		}
	}
}