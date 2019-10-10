module extrapanel.app.plugin.browser;

// Extra Panel
import extrapanel.app.ui;
import extrapanel.core.plugin.info;
import extrapanel.core.script.runner;
import extrapanel.core.util.exception;
import extrapanel.core.util.formatter;
import extrapanel.core.util.logger;
import extrapanel.core.util.paths;
import extrapanel.core.util.util;

// GDK
import gdk.Threads;
import gdkpixbuf.Pixbuf;

// GTK
import gtk.Box;
import gtk.Builder;
import gtk.Button;
import gtk.HBox;
import gtk.Image;
import gtk.Label;
import gtk.ListStore;
import gtk.Separator;
import gtk.TreeIter;
import gtk.VBox;
import gtk.Widget;

// Pango
import pango.PgAttributeList;

// STD
import std.concurrency;
import std.net.curl : download;
import std.path;

/**
 *	browser.d - Methods responsible for managing plugins and constructing GTK elements
 *
 * This file holds many helper methods to populate UI elements with plugin information,
 * as well as downloading/installing/uninstalling them.
 *
 * Authors: Ev1lbl0w
 */

enum ListStoreColumns : int { /// Enum containing the structure of elements inside a TreeView
	Installed,
	Logo,
	Text,
	Version,
	Type
}

/**
 * Populates the parent TreeView of plugins/packs/installed with all the plugins
 *
 * Params:
 *		pluginInfo = the PluginInfo to add to the TreeView.
 *		store = the ListStore from the TreeView.
 */
public static void populateList(PluginInfo pluginInfo, ListStore store) {
	TreeIter iterator = store.createIter();
	PluginManager pluginManager = PluginManager.getInstance();

	immutable bool installed = pluginManager.isPluginInstalled(pluginInfo);
	Pixbuf logo = new Pixbuf(buildPath(createTempPath(), "pc", pluginInfo.id ~ "-icon.png"));
	string text = bold(pluginInfo.name) ~ "\n" ~ pluginInfo.description;

	store.setValue(iterator, ListStoreColumns.Installed, installed);
	store.setValue(iterator, ListStoreColumns.Logo, logo);
	store.setValue(iterator, ListStoreColumns.Text, text);
	store.setValue(iterator, ListStoreColumns.Version, pluginInfo.strVersion);

	// Temporary hardcoded value, until we have a reliable method of identifying plugin types
	store.setValue(iterator, ListStoreColumns.Type, "Official");
}

/**
 * Builds the configuration panel for a plugin.
 *
 * A configuration panel will always be built and added to parent. If a file exists,
 * it will be loaded. Otherwise, a default panel will be created to indicate that the
 * plugin has no configuration menu.
 *
 * Params:
 *		info = the PluginInfo to build the config panel for.
 *		parent = the Widget that will act as a parent, receiving the config panel as a child.
 *		builder = a Builder class, used to load an UI from a file.
 */
public static void buildConfigPanel(PluginInfo info, Widget parent, Builder builder) {
	Box configBox = cast(Box) parent;

	// Retrieve needed singletons
	ScriptRunner scriptRunner = ScriptRunner.getInstance();
	PluginManager pluginManager = PluginManager.getInstance();

	// Creates the top level element with plugin meta info
	VBox topLevel = new VBox(false, 5);
	topLevel.setMarginTop(MARGIN_DEFAULT);
	topLevel.setMarginBottom(MARGIN_DEFAULT * 3);
	topLevel.setMarginStart(MARGIN_DEFAULT);
	topLevel.setMarginEnd(MARGIN_DEFAULT);

	// Creates the header info box
	HBox headerInfo = new HBox(false, 5);
	headerInfo.setHomogeneous(false);

	// Create a separator
	Separator sep = new Separator(GtkOrientation.HORIZONTAL);

	// Adds elements to the header: the plugin's logo, title and button area
	// Logo
	string logoPath = buildPath(pluginRootPath(info.id), info.icon);
	Image logo = new Image(logoPath);

	// Title
	Label title = new Label(info.name);
	PgAttributeList attribs = title.getAttributes() is null ? new PgAttributeList() : title.getAttributes();
	attribs.change(uiBold());
	title.setAttributes(attribs);

	// Button Area
	HBox buttonBox = new HBox(true, 2);
	buttonBox.setHexpand(true);
	buttonBox.setHalign(GtkAlign.END);

	// Info Button
	Button btInfo = new Button("Info");
	btInfo.setHalign(GtkAlign.CENTER);
	btInfo.setValign(GtkAlign.CENTER);
	pluginManager.mapWidgetWithPlugin(info, btInfo);
	btInfo.addOnClicked(&xPanelApp.openPluginInfo);

	// Uninstall Button
	Button btUninstall = new Button("Uninstall");
	btUninstall.setHalign(GtkAlign.CENTER);
	btUninstall.setValign(GtkAlign.CENTER);

	// Creates the main container for the plugin config
	Box configPanel;
	try {
		// If it's an advanced UI, load it's script
		scriptRunner.loadPlugin(info.id, ScriptType.CONFIG_SCRIPT);
		configPanel = new Box(scriptRunner.setupConfigMenu(info.id));
	} catch(FileNotFoundException e) {
		try {
			// If it's a simple UI, load it's definition file
			builder.addFromFile(buildPath(pluginRootPath(info.id), "configMenu.ui"));
			configPanel = cast(Box) builder.getObject(info.id ~ "_configWindow");
		} catch(Exception e) {
			// No UI could be found, create a simple UI stating that
			trace("Error caught: ", e.msg);
			warning("[", info.id, "] No config UI found.");

			configPanel = new Box(GtkOrientation.VERTICAL, 5);
			Label nothingFound = new Label("This plugin doesn't have a configuration menu.");
			PgAttributeList labelAttribs = new PgAttributeList();
			labelAttribs.change(uiItalic());
			labelAttribs.change(uiGrey());
			nothingFound.setAttributes(labelAttribs);
			configPanel.packStart(nothingFound, true, false, 0);
		}
	}

	// Add some margin
	configPanel.setMarginLeft(MARGIN_DEFAULT);
	configPanel.setMarginRight(MARGIN_DEFAULT);
	configPanel.setMarginBottom(MARGIN_DEFAULT);

	// Packs all the elements
	headerInfo.packStart(logo, false, false, 0);
	headerInfo.packStart(title, false, false, 0);
	buttonBox.packStart(btInfo, true, false, 0);
	buttonBox.packStart(btUninstall, true, false, 0);
	headerInfo.packStart(buttonBox, true, true, 0);

	topLevel.packStart(headerInfo, true, false, 0);
	topLevel.packStart(sep, true, false, 0);
	topLevel.packStart(configPanel, true, false, 0);

	configBox.packStart(topLevel, true, false, 0);
	configBox.showAll();
}

/**
 * Populates a plugin info page.
 *
 * Params:
 *		info = the PluginInfo to parse.
 *		builder = a Builder object to retrieve the UI elements to populate.
 */
public static void parseInfo(PluginInfo info, Builder builder) {
	// Retrieve the necessary elements
	Image pihIcon = cast(Image) builder.getObject("pihIcon");
	Label pihTitle = cast(Label) builder.getObject("pihTitle");
	Label pihDescription = cast(Label) builder.getObject("pihDescription");
	Label piiID = cast(Label) builder.getObject("piiID");
	Label piiVersion = cast(Label) builder.getObject("piiVersion");
	Label piiAuthors = cast(Label) builder.getObject("piiAuthors");
	Label piiURL = cast(Label) builder.getObject("piiURL");
	Label piiType = cast(Label) builder.getObject("piiType");

	// Populate the elements with data
	string logoPath = buildPath(pluginRootPath(info.id), info.icon);
	pihIcon.setFromFile(logoPath);
	pihTitle.setLabel(info.name);
	pihDescription.setLabel(info.description);

	piiID.setLabel(info.id);
	piiVersion.setLabel(info.strVersion);
	piiAuthors.setLabel(arrayToString(info.authors));
	piiURL.setLabel(url(info.url));
	piiType.setLabel("Official");
}

/**
 * Downloads a plugin to a temporary folder.
 *
 * Params:
 *		info = the PluginInfo to download.
 */
public static void downloadPlugin(PluginInfo info) {
	gdk.Threads.threadsAddIdle(&downloadPlugin_idleFetch, null);
	spawn(&thread_downloadPlugin, cast(immutable)info);
	thread_downloadPlugin_completed = false;
}

private shared bool thread_downloadPlugin_completed;
private void thread_downloadPlugin(immutable PluginInfo info) {
	string archiveFile = info.id ~ ".tar.gz";
	string archivePath = buildPath(CDN_PATH, info.id, archiveFile);

	download(archivePath, buildPath(createTempPath(), "pc", archiveFile));

	thread_downloadPlugin_completed = true;
}

extern(C) nothrow private int downloadPlugin_idleFetch(void* data) {
	try {
		if(thread_downloadPlugin_completed) return 0;
	} catch(Exception) return 0;

	return 1;
}

// Installs plugin in the local system
public static void installPlugin(PluginInfo info) {}

// Removes plugin from the local system
public static void uninstallPlugin(PluginInfo info) {}