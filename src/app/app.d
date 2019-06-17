module app.app;

import util.config;
import util.logger;
import util.paths;

import main;

import plugin.plugin;
import plugin.browser;

// STD
import std.stdio;
import std.json;
import std.path;
import std.file;
import std.conv;
import std.array;
import std.algorithm.searching;
import std.net.curl;
import std.concurrency;
import std.parallelism;
import std.process;

import core.thread;
import core.sys.posix.signal;

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
import gtk.Switch;
import gtk.Image;
import gtk.ListStore;
import gtk.TreeIter;
import gtk.Assistant;

// Top level
import gio.Application : GApplication = Application;

// Elements
import gio.Menu : GMenu = Menu;
import gio.MenuItem : GMenuItem = MenuItem;

// GDK
import gdk.Cursor;
import gdk.Threads;

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

static bool currentStatus = false;

shared bool fetching = false;

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

		Timeout timeout = new Timeout(250, &updateDaemonStatus);
	}

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

	// Assistant
	Assistant startWizard;
	Switch wizardInstallPack;

	// Meta Elements
	Button backButton, startButton, stopButton;
	Label status;
	ListStore pPluginsTreeModel;
	// Cursor's
	Cursor loadingCursor;

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
			Label pluginsLabel;
			Button wifiButton, bluetoothButton, usbButton;
			Label uuidLabel;
		Stack pluginsInterface;
			ScrolledWindow pPluginsInterface;
				Button ppRefresh;
				TreeView pPluginsTreeView;
			ScrolledWindow pPacksInterface;
				TreeView pPacksTreeView;
			ScrolledWindow pInstalledInterface;
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
				Button cpLocalInstall;
				Button cpLocalFolder;
			Box cDevicesInterface;
		Box aboutInterface;
		Box pluginInfoInterface;

	// Container for holding plugin ID's associated with buttons
	// This is a workaround because GtkD has no "clean" way to pass
	// user data to callbacks, which really annoys me.
	PluginInfo[Button] pluginInfoIds;

	Widget savedSidebar = null, savedInterface = null;

	// TID for fetching process
	Tid fetchTID;

	// Inits the builder defined elements
	void initElements()
	{
		// Top level
		window = cast(ApplicationWindow) builder.getObject("window");
		window.setApplication(this);

		startWizard = cast(Assistant) builder.getObject("startWizard");
		wizardInstallPack = cast(Switch) builder.getObject("wizardInstallPack");

		// Meta Elements
		backButton = cast(Button) builder.getObject("backButton");
		startButton = cast(Button) builder.getObject("startButton");
		stopButton = cast(Button) builder.getObject("stopButton");
		status = cast(Label) builder.getObject("status");
		pPluginsTreeModel = cast(ListStore) builder.getObject("pPluginsTreeModel");

		// General Tab Elements
		pluginsLabel = cast(Label) builder.getObject("pluginsLabel");
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
		pPluginsInterface = cast(ScrolledWindow) builder.getObject("pPluginsInterface");
		ppRefresh = cast(Button) builder.getObject("ppRefresh");
		pPluginsTreeView = cast(TreeView) builder.getObject("pPluginsTreeView");
		pPacksInterface = cast(ScrolledWindow) builder.getObject("pPacksInterface");
		pPacksTreeView = cast(TreeView) builder.getObject("pPacksTreeView");
		pInstalledInterface = cast(ScrolledWindow) builder.getObject("pInstalledInterface");
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
		cpLocalInstall = cast(Button) builder.getObject("cpLocalInstall");
		cpLocalFolder = cast(Button) builder.getObject("cpLocalFolder");
		cDevicesInterface = cast(Box) builder.getObject("cDevicesInterface");
		aboutInterface = cast(Box) builder.getObject("aboutInterface");
		pluginInfoInterface = cast(Box) builder.getObject("pluginInfoInterface");
	}

	void updateElements()
	{
		if(Configuration.isFirstTime()) {
			startWizard.addOnCancel(&wizardCanceled);
			startWizard.addOnApply(&wizardCompleted);

			window.setSensitive(false);
			startWizard.present();
		}
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
		startButton.addOnClicked(&startButtonCallback);
		stopButton.addOnClicked(&stopButtonCallback);

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

		cpLoadPlugins();
		cpLocalFolder.addOnClicked(&cpLocalFolderCallback);

		backButton.addOnClicked(&backButtonCallback);

		pPluginsInterface.addOnMap(&pPluginsRetrieveList);
		ppRefresh.addOnClicked(&ppRefreshCallback);

		// Queries the state of the daemon
		currentStatus = queryDaemon();
		updateMetaElements();

		loadingCursor = new Cursor(window.getDisplay(), GdkCursorType.WATCH);
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

	void startButtonCallback(Button b) {
		startDaemon();
	}

	void stopButtonCallback(Button b) {
		stopDaemon();
	}

	void openPluginInfo(Button button) {
		PluginInfo info = pluginInfoIds[button];
		if(info !is null) {
			logger.trace("Plugin info is: ", info.id);
			saveCurrentInterface();
			mainInterface.setVisibleChild(pluginInfoInterface);
			sidebar.setVisible(false);
			parseInfo(info, Template.Complete, null, builder);
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
			} else if(lbr == gAboutOption) {
					sidebar.setVisible(false);
					mainInterface.setVisibleChild(aboutInterface);
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
		if(savedSidebar !is null && savedInterface !is null) {
			logger.trace("backButtonCallback(): restoring interface.");
			restoreSavedInterface();
			sidebar.setVisible(true);
		} else {
			logger.trace("backButtonCallback(): going to main interface.");
			sidebar.setVisibleChild(generalBar);
			mainInterface.setVisibleChild(generalInterface);
			backButton.setVisible(false);
			sidebar.setVisible(true);
		}
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

	void startDaemon() {
		spawnProcess("extrapanel-daemon");
	}

	void stopDaemon() {
		string pidStr = getDaemonPID();
		if(find(getProcFile(pidStr), "extrapanel-daemon")) {
			kill(to!(int)(pidStr), SIGTERM);
			//spawnProcess(["kill", "-15", pidStr]);
		}
	}

	bool queryDaemon() {
		if(exists(appConfigPath ~ LOCK_PATH)) {
			string pid = getDaemonPID();
			logger.trace(pid);
			try {
				string line = getProcFile(pid);
				if(find(line, "extrapanel-daemon"))
					return true;
			} catch(Exception e) {
				return false;
			}
		}
		return false;
	}

	string getDaemonPID() {
		return File(appConfigPath ~ LOCK_PATH, "r").readln();
	}

	string getProcFile(string pid) {
		return File("/proc/" ~ pid ~ "/cmdline", "r").readln();
	}

	void cpLoadPlugins() {
		logger.trace("Showed up");

		pluginsLabel.setLabel("Plugins: " ~ to!string(getInstalledPlugins().length));

		// Empty the container
		foreach(id; getInstalledPlugins()) {
			parseInfo(new PluginInfo(id), Template.ConfigElement, cpPanels, builder);
		}
	}

	void cpLocalFolderCallback(Button b) {
		string path = "file:///" ~ pluginRootPath();
		logger.trace("path: ", path);
		import gio.AppInfoIF;
		AppInfoIF.launchDefaultForUri(path, null);
	}

	void saveCurrentInterface() {
		savedSidebar = sidebar.getVisibleChild();
		savedInterface = mainInterface.getVisibleChild();
	}

	void restoreSavedInterface() {
		sidebar.setVisibleChild(savedSidebar);
		mainInterface.setVisibleChild(savedInterface);
		savedSidebar = null;
		savedInterface = null;
	}

	bool once = false;

	void pPluginsRetrieveList(Widget w) {
		logger.trace("pPluginsRetrieveList called");
		if(!once) {
			once = true;
			ppRefresh.setSensitive(false);
			setCursorLoading(true);
			logger.trace("Spawning fetching thread...");
			gdk.Threads.threadsAddIdle(&processIdleFetch, null);
			fetchTID = spawn(&fetchPlugins);
			fetching = true;
		}
	}

	void ppRefreshCallback(Button b) {
		pPluginsTreeModel.clear();
		once = false;
		pPluginsRetrieveList(null);
	}

	void addPluginListElement(PluginInfo pluginInfo) {
		populateList(pluginInfo, pPluginsTreeModel);
	}

	void setCursorLoading(bool loading) {
		logger.trace(loadingCursor.getCursorType());
		window.getWindow().setCursor(loading ? loadingCursor : null);
		logger.trace(window.getWindow().getCursor() == loadingCursor ? "true" : "false");
	}

	void wizardCanceled(Assistant a) {
		this.window.close();
	}

	void wizardCompleted(Assistant a) {
		logger.trace(wizardInstallPack);
		bool installPack = wizardInstallPack.getActive();
		logger.info("Wizard completed successfully, and user's choice yas ", installPack);
		this.startWizard.hide();
		this.window.setSensitive(true);
		Configuration.setOption(Options.AcceptedWizard, true);
	}
}

void fetchPlugins() {
	string cdnMetaPath = CDN_PATH ~ "meta.json";
	string localMetaPath = buildPath(createTempPath(), "pc", "meta.json");

	download(cdnMetaPath, localMetaPath);
	JSONValue metaJson = parseJSON(readText(localMetaPath));

	Tid parentTid = ownerTid();
	
	foreach(plugin; taskPool.parallel(metaJson["official"].array)) {
		try {
			string localPluginMetaPath = buildPath(createTempPath(), "pc", plugin.str.replace("/", "-"));
			string localPluginIconPath = buildPath(createTempPath(), "pc", plugin.str.replace("/meta.json", "-icon.png"));
			string logoCdnPath = plugin.str.replace("meta.json", "icon.png");
			download(CDN_PATH ~ plugin.str, localPluginMetaPath);
			download(CDN_PATH ~ logoCdnPath, localPluginIconPath);
			immutable JSONValue pluginJson = parseJSON(readText(localPluginMetaPath));

			parentTid.send(pluginJson);
		} catch(Throwable t) {
			writeln("Error: ", t);
		}
	}

	fetching = false;
}

extern(C) nothrow static int processIdleFetch(void* data) {
	try {
		receiveTimeout(dur!("msecs")(10), (immutable JSONValue pluginJson) {
			xPanelApp.addPluginListElement(new PluginInfo(pluginJson));
		});

		if(!fetching) {
			xPanelApp.setCursorLoading(false);
			xPanelApp.ppRefresh.setSensitive(true);
			return 0;
		}
	} catch(Throwable t) {
		try {
			writeln("Error! ", t);
		} catch(Throwable t) {}
		return 0;
	}

	return 1;
}