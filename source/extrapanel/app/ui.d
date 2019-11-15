module extrapanel.app.ui;

// Core
import core.sys.posix.signal;
import core.thread;

// Extra Panel
import extrapanel.app.plugin.browser;
import extrapanel.core.plugin.info;
import extrapanel.core.script.runner;
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
import gtk.ProgressBar;
import gtk.ScrolledWindow;
import gtk.SpinButton;
import gtk.Spinner;
import gtk.Stack;
import gtk.Switch;
import gtk.ToggleButton;
import gtk.TreeIter;
import gtk.TreePath;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;

// Pango
import pango.PgAttributeList;

// STD
import std.algorithm.searching;
import std.array;
import std.concurrency;
import std.conv;
//import std.file;
import std.json;
import std.net.curl : download;
import std.parallelism;
import std.process;
import std.stdio;
import std.string;

/**
 *	app.d - Main UI manager for the app
 */

enum State {
	Online,
	Offline,
	Disabled
}

private static State wifiState = State.Disabled, bluetoothState = State.Disabled, usbState = State.Disabled;

private static bool currentStatus, pluginsConfigLoaded, pluginsBrowserLoaded;
private shared bool fetching;

static ExtraPanelGUI xPanelApp; /// The global instance of the UI.

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

	/**
	 * Sets a connection state to a button.
	 *
	 * Depending on the connection state, modifies the button to represent that state properly.
	 *
	 * Params:
	 *  button = the Button to modify.
	 *		state = the State to present.
	 */
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

	/**
	 * Opens the plugin info panel associated with a button.
	 *
	 * This is a workaround for GtkD not allowing to pass user_data to callbacks.
	 *
	 * Params:
	 *  button = the Button associated with a PluginInfo.
	 */
	void openPluginInfo(Button button) {
		PluginInfo info = pluginManager.getMappedPlugin(button);
		if(info !is null) {
			trace("Plugin info is: ", info.id);
			saveCurrentInterface();
			mainInterface.setVisibleChild(pluginInfoInterface);
			pluginManager.mapWidgetWithPlugin(info, piaUninstall);
			sidebar.setVisible(false);
			parseInfo(info, builder);
		}
	}

	void lockWindowControl(bool value) {
		window.setSensitive(!value);
		setCursorLoading(value);
	}

	void btUninstall_onClicked(Button button) {
		lockWindowControl(true);
		PluginInfo pInfo = pluginManager.getMappedPlugin(button);
		trace(pInfo);
		uninstallPlugin(pInfo);
	}

	void uninstallRetCode(string id, int retCode) {
		lockWindowControl(false);
		if(!retCode) {
			trace("Uninstall successfull!");
			pluginListChanged();
			if(savedInterface)
				restoreSavedInterface();
			TreeIter it = pluginManager.findTreeIterWithId(id);
			if(it)
				pPluginsTreeModel.setValue(it, ListStoreColumns.Installed, false);
		}
	}

	void installRetCode(string id, int retCode) {
		lockWindowControl(false);
		if(!retCode) {
			trace("Install successfull!");
			pStatus.setText("Installed " ~ id);
			pluginListChanged();
			TreeIter it = pPluginsTreeView.getSelectedIter();
			if(it)
				pPluginsTreeModel.setValue(it, ListStoreColumns.Installed, true);
		}
	}

	/**
	 * Adds a PluginInfo to the TreeView.
	 *
	 * Params:
	 *  pluginInfo = the PluginInfo to add.
	 */
	void addPluginListElement(PluginInfo pluginInfo) {
		populateList(pluginInfo, pPluginsTreeModel);
	}

	void pluginListChanged() {
		pluginManager.updateInstalledPluginList();
		scriptRunner.cleanup();
		pluginsLabel.setLabel("Plugins: " ~ to!string(pluginManager.getInstalledPlugins().length));
		cpLoadPlugins(true);
	}

private:
	// Plugin Manager
	PluginManager pluginManager;

	// Script Runner
	ScriptRunner scriptRunner;

	// Constructor
	Builder builder;

	// Window
	ApplicationWindow window;

	// Assistant
	Assistant startWizard;
	Switch wizardInstallPack;

	// Meta Elements
	Button backButton;
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
			Button piaReset;
			Button piaUninstall;

	// Bottom Bar
	Stack statusBar;
		Box daemonStatusBar;
			Label dStatus;
			Button dStartButton;
			Button dStopButton;
		Box pluginStatusBar;
			Label pStatus;
			Spinner pSpinner;
			ProgressBar pProgressBar;
			Button pActionButton;

	Widget savedSidebar = null, savedInterface = null, savedStatusBar = null;

	// TID for fetching process
	Tid fetchTID;

	// Values for plugin fetching
	int maxPlugins, currPlugin;

	// App activated
	void onAppActivate(GApplication app) {
		trace("Activate App Signal");
		// Detect if there are other instances of this app running
		if (!app.getIsRemote() && window is null)
		{
			// Loads the UI files
			trace("Primary instance, loading UI...");
			builder = new Builder();
			if(!builder.addFromResource("/org/aurorafoss/extrapanel/ui/window.ui"))
			{
				critical("Window resource cannot be found");
				return;
			}

			// Setup the app
			initElements();
			updateElements();
		} else {
			trace("Another instance exists, taking control...");
		}

		// Show
		this.window.present();
		if(Configuration.isFirstTime)
			lockWindowControl(true);
	}

	void onAppDestroy(GApplication) {
		// Saves Configs
		ScriptRunner.getInstance().cleanup();
		Configuration.save();
	}

	// Inits the builder defined elements
	void initElements()
	{
		trace("Initializing elements...");

		// Top level
		window = cast(ApplicationWindow) builder.getObject("window");
		window.setApplication(this);

		// Start Wizard
		startWizard = cast(Assistant) builder.getObject("startWizard");
		wizardInstallPack = cast(Switch) builder.getObject("wizardInstallPack");

		// Meta Elements
		backButton = cast(Button) builder.getObject("backButton");
		dStartButton = cast(Button) builder.getObject("dStartButton");
		dStopButton = cast(Button) builder.getObject("dStopButton");
		dStatus = cast(Label) builder.getObject("dStatus");
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
		piaReset = cast(Button) builder.getObject("piaReset");
		piaUninstall = cast(Button) builder.getObject("piaUninstall");

		// Bottom Bar
		statusBar = cast(Stack) builder.getObject("statusBar");
		daemonStatusBar = cast(Box) builder.getObject("daemonStatusBar");
		dStatus = cast(Label) builder.getObject("dStatus");
		dStartButton = cast(Button) builder.getObject("dStartButton");
		dStopButton = cast(Button) builder.getObject("dStopButton");
		pluginStatusBar = cast(Box) builder.getObject("pluginStatusBar");
		pStatus = cast(Label) builder.getObject("pStatus");
		pSpinner = cast(Spinner) builder.getObject("pSpinner");
		pProgressBar = cast(ProgressBar) builder.getObject("pProgressBar");
		pActionButton = cast(Button) builder.getObject("pActionButton");

		// Singletons
		pluginManager = PluginManager.getInstance();
		scriptRunner = ScriptRunner.getInstance();

		loadingCursor = new Cursor(window.getDisplay(), GdkCursorType.WATCH);
	}

	void updateElements()
	{
		trace("Connection callbacks...");

		// If it's the first time the app is launcher, show the starting wizard
		if(Configuration.isFirstTime()) {
			startWizard.addOnCancel(&startWizard_onCancel);
			startWizard.addOnApply(&startWizard_onApply);

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
		cgCommDelay.setValue(Configuration.getOption!(float)(Options.CommDelay));
		cgOpenAppStartup.setActive(Configuration.getOption!(bool)(Options.LoadOnBoot));
		uuidLabel.setLabel("UUID: " ~ Configuration.getOption!(string)(Options.DeviceUUID));

		// Update UI state for communication
		setConnectionButtonState(wifiButton, wifiState);
		setConnectionButtonState(bluetoothButton, bluetoothState);
		setConnectionButtonState(usbButton, usbState);

		// Callbacks
		dStartButton.addOnClicked(&startButton_onClicked);
		dStopButton.addOnClicked(&stopButton_onClicked);

		generalBar.addOnRowActivated(&sidebar_onRowActivated);
		pluginsBar.addOnRowActivated(&sidebar_onRowActivated);
		configBar.addOnRowActivated(&sidebar_onRowActivated);

		wifiButton.addOnClicked(&connectionButton_onClicked);
		bluetoothButton.addOnClicked(&connectionButton_onClicked);
		usbButton.addOnClicked(&connectionButton_onClicked);

		cgCommDelay.addOnValueChanged(&cgCommDelay_onValueChanged);
		cgOpenAppStartup.addOnToggled(&cgOpenAppStartup_onToggled);

		ccwEnableCheck.addOnToggled(&ccEnableCheck_onToggled);
		ccbEnableCheck.addOnToggled(&ccEnableCheck_onToggled);
		ccuEnableCheck.addOnToggled(&ccEnableCheck_onToggled);

		cPluginsInterface.addOnMap(&cPluginsInterface_onMap);
		cpLocalFolder.addOnClicked(&cpLocalFolder_onClicked);

		backButton.addOnClicked(&backButton_onClicked);

		pPluginsInterface.addOnMap(&pPluginsInterface_onMap);
		pPluginsTreeView.addOnCursorChanged(&pPluginsTreeView_onCursorChanged);
		pActionButton.addOnClicked(&pActionButton_onClicked);
		ppRefresh.addOnClicked(&ppRefresh_onClicked);

		pluginInfoInterface.addOnUnmap(&pPluginsInfoInterface_onUnmap);
		piaUninstall.addOnClicked(&btUninstall_onClicked);

		// Queries the state of the daemon
		currentStatus = queryDaemon();
		updateMetaElements();
		pluginListChanged();
	}

	// Callbacks
	void startWizard_onCancel(Assistant) {
		trace("startWizard: canceled");
		this.window.close();
	}

	void startWizard_onApply(Assistant) {
		trace("startWizard: completed");
		immutable bool installPack = wizardInstallPack.getActive();
		this.startWizard.hide();
		lockWindowControl(false);
		Configuration.setOption(Options.AcceptedWizard, true);
	}

	void startButton_onClicked(Button) {
		trace("dStartButton: clicked");
		startDaemon();
	}

	void stopButton_onClicked(Button) {
		trace("dStopButton: clicked");
		stopDaemon();
	}

	void sidebar_onRowActivated(ListBoxRow lbr, ListBox lb) {
		trace("Sidebar: row activated");
		backButton.setVisible(true);
		if(lb == generalBar) {
			if(lbr == gConfigOption) {
					trace("\tconfigOption: changing to config interface");
					sidebar.setVisibleChild(configBar);
					mainInterface.setVisibleChild(configInterface);
					configInterface.setVisibleChild(cGeneralInterface);
			} else if(lbr == gPluginsOption) {
					trace("\tpluginsOption: changing to plugins");
					sidebar.setVisibleChild(pluginsBar);
					mainInterface.setVisibleChild(pluginsInterface);
					statusBar.setVisibleChild(pluginStatusBar);
			} else if(lbr == gAboutOption) {
					trace("\taboutOption: changing to about");
					sidebar.setVisible(false);
					mainInterface.setVisibleChild(aboutInterface);
			}
		} else if(lb == pluginsBar) {

		} else if(lb == configBar) {
			if(lbr == cGeneralOption) {
				trace("\tgeneralOutton: clicked");
				configInterface.setVisibleChild(cGeneralInterface);
			} else if(lbr == cConnectionOption) {
				trace("\tconnectionOutton: clicked");
				configInterface.setVisibleChild(cConnectionInterface);
			} else if(lbr == cPluginsOption) {
				trace("\tpluginsOutton: clicked");
				configInterface.setVisibleChild(cPluginsInterface);
			} else if(lbr == cDevicesOption) {
				trace("\tdevicesOutton: clicked");
				configInterface.setVisibleChild(cDevicesInterface);
			}
		}
	}

	void connectionButton_onClicked(Button b) {
		trace("connectionButton: clicked");
		if(b == wifiButton) {
			trace("\twifiButton: toggled");
			wifiState = wifiState is State.Online ? State.Offline : State.Online;
			setConnectionButtonState(wifiButton, wifiState);
		} else if (b == bluetoothButton) {
			trace("\tbluetoothButton: toggled");
			bluetoothState = bluetoothState is State.Online ? State.Offline : State.Online;
			setConnectionButtonState(bluetoothButton, bluetoothState);
		} else if (b == usbButton) {
			trace("\tusbButton: toggled");
			usbState = usbState is State.Online ? State.Offline : State.Online;
			setConnectionButtonState(usbButton, usbState);
		}
	}

	void cgCommDelay_onValueChanged(SpinButton sb) {
		Configuration.setOption(Options.CommDelay, sb.getValue());
	}

	void cgOpenAppStartup_onToggled(ToggleButton tb) {
		trace("Config -> General -> openAppStartup: toggled");
		Configuration.setOption(Options.LoadOnBoot, tb.getActive());
	}

	void ccEnableCheck_onToggled(ToggleButton tb) {
		trace("Config -> Connection -> enableCheck: toggled");
		immutable State state = tb.getActive() ? State.Offline : State.Disabled;
		if(tb == ccwEnableCheck) {
			trace("\twifiEnableCheck: toggled");
			wifiState = state;
			Configuration.setOption(Options.WiFiEnabled, tb.getActive());
			setConnectionButtonState(wifiButton, wifiState);
		} else if(tb == ccbEnableCheck) {
			trace("\tbluetoothEnableCheck: toggled");
			bluetoothState = state;
			Configuration.setOption(Options.BluetoothEnabled, tb.getActive());
			setConnectionButtonState(bluetoothButton, bluetoothState);
		} else if(tb == ccuEnableCheck) {
			trace("\tusbEnableCheck: toggled");
			usbState = state;
			Configuration.setOption(Options.UsbEnabled, tb.getActive());
			setConnectionButtonState(usbButton, usbState);
		}
	}

	void cpLocalFolder_onClicked(Button) {
		trace("Config -> Plugins -> cpLocalFolder: clicked");
		string path = "file://" ~ pluginRootPath();
		trace("Opening file explorer for path: ", path);
		import gio.AppInfoIF : AppInfoIF;
		AppInfoIF.launchDefaultForUri(path, null);
	}

	void backButton_onClicked(Button) {
		trace("backButton: clicked");
		if(savedSidebar !is null && savedInterface !is null) {
			trace("\trestoring interface.");
			restoreSavedInterface();
		} else {
			trace("\tgoing back to main interface.");
			sidebar.setVisibleChild(generalBar);
			mainInterface.setVisibleChild(generalInterface);
			statusBar.setVisibleChild(daemonStatusBar);
			backButton.setVisible(false);
			sidebar.setVisible(true);
		}
	}

	void pPluginsInterface_onMap(Widget) {
		if(!pluginsBrowserLoaded) {
			pluginsBrowserLoaded = true;
			fetching = true;
			trace("Plugins -> pPluginsInterface: map");
			setCursorLoading(true);
			trace("\tSpawning plugin fetching thread...");
			ppRefresh.setSensitive(false);
			gdk.Threads.threadsAddIdle(&processIdleFetch, null);
			fetchTID = spawn(&fetchPlugins);
		}
	}

	void pPluginsTreeView_onCursorChanged(TreeView tv) {
		trace("here");
		if(!fetching) {
			PluginInfo pInfo = pluginManager.getMappedTreeIter(tv.getSelectedIter());
			pActionButton.setSensitive(!pInfo.installed);
		}
	}

	void pActionButton_onClicked(Button) {
		TreeIter it = pPluginsTreeView.getSelectedIter();
		PluginInfo pInfo = pluginManager.getMappedTreeIter(it);
		pActionButton.setSensitive(false);
		pStatus.setText("Downloading " ~ pInfo.id ~ "...");
		downloadPlugin(pInfo);
		pStatus.setText("Installing " ~ pInfo.id ~ "...");
		lockWindowControl(true);
		installPlugin(pInfo);
	}

	void ppRefresh_onClicked(Button) {
		pluginsBrowserLoaded = false;
		fetching = true;
		trace("Plugins -> ppRefresh: clicked");
		pPluginsTreeModel.clear();
		pluginManager.updateInstalledPluginList();
		pluginManager.clearTreeIterMap();
		pPluginsInterface_onMap(null);
	}

	void pPluginsInfoInterface_onUnmap(Widget) {
		pluginManager.unmapWidget(piaUninstall);
	}

	bool updateDaemonStatus() {
		immutable bool newStatus = queryDaemon();
		if(currentStatus != newStatus) {
			currentStatus = newStatus;
			updateMetaElements();
		}
		return true;
	}

	void updateMetaElements() {
		dStopButton.setSensitive(currentStatus);
		dStartButton.setSensitive(!currentStatus);
		dStatus.setLabel(currentStatus ? "Running" : "Stopped");

		PgAttributeList attrs = dStatus.getAttributes() is null ? new PgAttributeList() : dStatus.getAttributes();
		attrs.change(currentStatus ? uiGreen() : uiRed());
		dStatus.setAttributes(attrs);
	}

	void startDaemon() {
		if(wait(spawnProcess("extrapanel-daemon")))
			warning("Daemon failed to launch!!");
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
			try {
				string line = getProcFile(pid);
				if(find(line, "extrapanel-daemon"))
					return true;
			} catch(Exception) {
				return false;
			}
		}
		return false;
	}

	string getDaemonPID() {
		return File(buildPath(appConfigPath, PID_PATH), "r").readln();
	}

	string getProcFile(string pid) {
		return File("/proc/" ~ pid ~ "/cmdline", "r").readln();
	}

	void cPluginsInterface_onMap(Widget) {
		cpLoadPlugins();
	}

	void cpLoadPlugins(bool forceRefresh = false) {
		trace("Config -> Plugins: Loading plugin configuration menu's");

		if(forceRefresh)
			cpPanels.removeAll();

		// Empty the container
		if(!pluginsConfigLoaded || forceRefresh) {
			pluginsConfigLoaded = true;
			PluginInfo[] pluginList = pluginManager.getInstalledPlugins(forceRefresh);
			foreach(pluginInfo; pluginList) {
				buildConfigPanel(pluginInfo, cpPanels, builder);
			}
			cpPanels.showAll();
		}
	}

	void saveCurrentInterface() {
		savedSidebar = sidebar.getVisibleChild();
		savedInterface = mainInterface.getVisibleChild();
		savedStatusBar = statusBar.getVisibleChild();
	}

	void restoreSavedInterface() {
		sidebar.setVisibleChild(savedSidebar);
		mainInterface.setVisibleChild(savedInterface);
		statusBar.setVisibleChild(savedStatusBar);
		sidebar.setVisible(true);
		savedSidebar = null;
		savedInterface = null;
		savedStatusBar = null;
	}

	void setCursorLoading(bool loading) {
		trace(window);
		trace(window.getWindow());
		trace(loading);
		trace(loadingCursor);
		window.getWindow().setCursor(loading ? loadingCursor : null);
	}
}

void fetchPlugins() {
	string cdnMetaPath = CDN_PATH ~ "meta.json";
	string localMetaPath = buildPath(createTempPath(), "pc", "meta.json");

	download(cdnMetaPath, localMetaPath);
	JSONValue metaJson = parseJSON(readText(localMetaPath));

	Tid parentTid = ownerTid();
	parentTid.send(to!int(metaJson["official"].array.length));

	foreach(plugin; taskPool.parallel(metaJson["official"].array)) {
		try {
			string rootPath = buildPath(createTempPath(), "pc", plugin.str.replace("/meta.json", ""));
			mkdir(rootPath);
			immutable string localPluginMetaPath = buildPath(rootPath, "meta.json");
			immutable string localPluginIconPath = buildPath(rootPath, "icon.png");
			immutable string logoCdnPath = plugin.str.replace("meta.json", "icon.png");
			download(CDN_PATH ~ plugin.str, localPluginMetaPath);
			download(CDN_PATH ~ logoCdnPath, localPluginIconPath);
			immutable JSONValue pluginJson = parseJSON(readText(localPluginMetaPath));
			parentTid.send(pluginJson);
		} catch(Exception e) {}
	}

	fetching = false;
}

extern(C) nothrow static int processIdleFetch(void* data) {
	try {
		receiveTimeout(dur!("msecs")(10), (int maxPlugins) {
			xPanelApp.maxPlugins = maxPlugins;
			xPanelApp.currPlugin = 0;
			xPanelApp.pProgressBar.setFraction(0);
			xPanelApp.pSpinner.start();
		});
		receiveTimeout(dur!("msecs")(10), (immutable JSONValue pluginJson) {
			xPanelApp.addPluginListElement(new PluginInfo(pluginJson));
			xPanelApp.currPlugin++;
			xPanelApp.pStatus.setText("Finished downloading plugin " ~ pluginJson["id"].str);
			xPanelApp.pProgressBar.setFraction(to!float(xPanelApp.currPlugin) / xPanelApp.maxPlugins);
		});

		if(!fetching && xPanelApp.maxPlugins == xPanelApp.currPlugin) {
			xPanelApp.setCursorLoading(false);
			xPanelApp.ppRefresh.setSensitive(true);
			xPanelApp.pSpinner.stop();
			xPanelApp.pStatus.setText("Finished fetching plugins");
			xPanelApp.ppRefresh.setSensitive(true);
			return 0;
		}
	} catch(Exception e) {
		try {
			writeln("Error! ", e);
		} catch(Exception) {}
		return 0;
	}

	return 1;
}