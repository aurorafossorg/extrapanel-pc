module extrapanel.app.ui;

// Core
import core.sys.posix.signal;
import core.thread;

// Extra Panel
import extrapanel.app.plugin.browser;
import extrapanel.core.plugin.info;
import extrapanel.core.util.config;
import extrapanel.core.util.formatter;
import extrapanel.core.util.logger;
import extrapanel.core.util.paths;

// GDK
import gdk.Cursor;
import gdk.Threads;

// GLib
import glib.Timeout;

// GIO
import gio.Application : GApplication = Application;

// GTK
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Assistant;
import gtk.Box;
import gtk.Builder;
import gtk.Button;
import gtk.CheckButton;
import gtk.Label;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.ListStore;
import gtk.Notebook;
import gtk.ScrolledWindow;
import gtk.SpinButton;
import gtk.Stack;
import gtk.Switch;
import gtk.ToggleButton;
import gtk.TreeView;
import gtk.Widget;

// Pango
import pango.PgAttributeList;

// STD
import std.algorithm.searching;
import std.array;
import std.concurrency;
import std.conv;
import std.file;
import std.json;
import std.net.curl;
import std.parallelism;
import std.process;
import std.stdio;

/**
 *	app.d - Main UI manager for the app
 */

enum State {
	Online,
	Offline,
	Disabled
}

static State wifiState = State.Disabled, bluetoothState = State.Disabled, usbState = State.Disabled;

static bool currentStatus = false;

shared bool fetching = false;

static ExtraPanelGUI xPanelApp;

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
		super("org.aurorafoss.extrapanel.ui", flags);
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

	// Plugin Manager
	PluginManager pluginManager;

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

	Widget savedSidebar = null, savedInterface = null;

	// TID for fetching process
	Tid fetchTID;

	// Inits the builder defined elements
	void initElements()
	{
		// Top level
		window = cast(ApplicationWindow) builder.getObject("window");
		window.setApplication(this);

		// Start Wizard
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

		// Plugin Manager
		pluginManager = PluginManager.getInstance();
	}

	void updateElements()
	{
		// If it's the first time the app is launcher, show the starting wizard
		if(Configuration.isFirstTime()) {
			startWizard.addOnCancel(&startWizard_onCancel);
			startWizard.addOnApply(&startWizard_onApply);

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
		startButton.addOnClicked(&startButton_onClicked);
		stopButton.addOnClicked(&stopButton_onClicked);

		generalBar.addOnRowActivated(&sidebar_onRowActivated);
		pluginsBar.addOnRowActivated(&sidebar_onRowActivated);
		configBar.addOnRowActivated(&sidebar_onRowActivated);

		wifiButton.addOnClicked(&connectionButton_onClicked);
		bluetoothButton.addOnClicked(&connectionButton_onClicked);
		usbButton.addOnClicked(&connectionButton_onClicked);

		cgOpenAppStartup.addOnToggled(&cgOpenAppStartup_onToggled);

		ccwEnableCheck.addOnToggled(&ccEnableCheck_onToggled);
		ccbEnableCheck.addOnToggled(&ccEnableCheck_onToggled);
		ccuEnableCheck.addOnToggled(&ccEnableCheck_onToggled);

		cpLoadPlugins();
		cpLocalFolder.addOnClicked(&cpLocalFolder_onClicked);

		backButton.addOnClicked(&backButton_onClicked);

		pPluginsInterface.addOnMap(&pPluginsInterface_onMap);
		ppRefresh.addOnClicked(&ppRefresh_onClicked);

		// Queries the state of the daemon
		currentStatus = queryDaemon();
		updateMetaElements();

		loadingCursor = new Cursor(window.getDisplay(), GdkCursorType.WATCH);
	}

	// Callbacks
	void startWizard_onCancel(Assistant a) {
		this.window.close();
	}

	void startWizard_onApply(Assistant a) {
		logger.trace(wizardInstallPack);
		bool installPack = wizardInstallPack.getActive();
		logger.info("Wizard completed successfully, and user's choice yas ", installPack);
		this.startWizard.hide();
		this.window.setSensitive(true);
		Configuration.setOption(Options.AcceptedWizard, true);
	}

	void startButton_onClicked(Button b) {
		startDaemon();
	}

	void stopButton_onClicked(Button b) {
		stopDaemon();
	}

	void sidebar_onRowActivated(ListBoxRow lbr, ListBox lb) {
		logger.trace("sidebar_onRowActivated()");
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

	void connectionButton_onClicked(Button b) {
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

	void cgOpenAppStartup_onToggled(ToggleButton tb) {
		Configuration.setOption(Options.LoadOnBoot, tb.getActive());
	}

	void ccEnableCheck_onToggled(ToggleButton tb) {
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

	void cpLocalFolder_onClicked(Button b) {
		string path = "file://" ~ pluginRootPath();
		logger.trace("path: ", path);
		import gio.AppInfoIF;
		AppInfoIF.launchDefaultForUri(path, null);
	}

	void backButton_onClicked(Button b) {
		if(savedSidebar !is null && savedInterface !is null) {
			logger.trace("backButton_onClicked(): restoring interface.");
			restoreSavedInterface();
			sidebar.setVisible(true);
		} else {
			logger.trace("backButton_onClicked(): going to main interface.");
			sidebar.setVisibleChild(generalBar);
			mainInterface.setVisibleChild(generalInterface);
			backButton.setVisible(false);
			sidebar.setVisible(true);
		}
	}

	bool once = false;
	void pPluginsInterface_onMap(Widget w) {
		logger.trace("pPluginsInterface_onMap called");
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

	void ppRefresh_onClicked(Button b) {
		pPluginsTreeModel.clear();
		once = false;
		pPluginsInterface_onMap(null);
	}

	// Helper methods
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
				attrs.change(uiGreen());
				label.setAttributes(attrs);

				break;
			case State.Offline:
				button.setSensitive(true);
				Label label = cast(Label) builder.getObject(id ~ "Label");
				label.setLabel("Offline");
				PgAttributeList attrs = label.getAttributes() is null ? new PgAttributeList() : label.getAttributes();
				attrs.change(uiRed());
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

	void openPluginInfo(Button button) {
		PluginInfo info = pluginManager.getMappedPlugin(button);
		if(info !is null) {
			logger.trace("Plugin info is: ", info.id);
			saveCurrentInterface();
			mainInterface.setVisibleChild(pluginInfoInterface);
			sidebar.setVisible(false);
			parseInfo(info, builder);
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
		attrs.change(currentStatus ? uiGreen() : uiRed());
		status.setAttributes(attrs);
	}

	void startDaemon() {
		if(wait(spawnProcess("extrapanel-daemon")))
			logger.warning("Daemon failed to launch!!");
	}

	void stopDaemon() {
		string pidStr = getDaemonPID();
		if(find(getProcFile(pidStr), "extrapanel-daemon")) {
			kill(to!(int)(pidStr), SIGTERM);
		}
	}

	bool queryDaemon() {
		if(exists(buildPath(appConfigPath, LOCK_PATH))) {
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
		return File(buildPath(appConfigPath, LOCK_PATH), "r").readln();
	}

	string getProcFile(string pid) {
		return File("/proc/" ~ pid ~ "/cmdline", "r").readln();
	}

	void cpLoadPlugins() {
		logger.trace("Showed up");

		pluginsLabel.setLabel("Plugins: " ~ to!string(pluginManager.getInstalledPlugins().length));

		// Empty the container
		foreach(pluginInfo; pluginManager.getInstalledPlugins()) {
			buildConfigPanel(pluginInfo, cpPanels, builder);
		}
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

	void addPluginListElement(PluginInfo pluginInfo) {
		populateList(pluginInfo, pPluginsTreeModel);
		downloadPlugin(pluginInfo);
	}

	void setCursorLoading(bool loading) {
		logger.trace(loadingCursor.getCursorType());
		window.getWindow().setCursor(loading ? loadingCursor : null);
		logger.trace(window.getWindow().getCursor() == loadingCursor ? "true" : "false");
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
		} catch(Throwable t) {}
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