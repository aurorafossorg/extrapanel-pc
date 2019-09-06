module extrapanel.app.plugin.browser;

import std.path;
import std.file;
import std.algorithm.searching;
import std.concurrency;
import std.parallelism;
import std.process;

import extrapanel.app.main;

import extrapanel.core.plugin.info;
import extrapanel.core.util.paths;
import extrapanel.core.util.logger;
import extrapanel.core.util.util;
import extrapanel.core.util.exception;
import extrapanel.core.util.config;
import extrapanel.core.util.formatter;
import extrapanel.core.script.runner;

import gtk.c.types;
import pango.c.types;

import gtk.Builder;
import gtk.TreeView;
import gtk.Widget;
import gtk.Box;
import gtk.VBox;
import gtk.HBox;
import gtk.Label;
import gtk.Image;
import gtk.Window;
import gtk.Separator;
import gtk.Button;
import gtk.Stack;
import gtk.ListStore;
import gtk.TreeIter;
import gobject.Signals;

import gdkpixbuf.Pixbuf;
import gdk.Threads;

import pango.PgAttributeList;
import pango.PgAttribute;

import riverd.lua.statfun;
import riverd.lua.types;

import std.json;
import std.string;
import std.net.curl;

/**
 *	browser.d - Methods responsible for managing plugins and constructing GTK elements
 */

enum ListStoreColumns : int {
	Installed,
	Logo,
	Text,
	Version,
	Type
}

// Methods that populate GTK objects with plugin info

// Populates the parent TreeView of plugins/packs/installed with all the plugins
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

// Builds the config panel for a plugin
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
			logger.trace(info.id ~ "_configWindow");
			configPanel = cast(Box) builder.getObject(info.id ~ "_configWindow");
			logger.trace("Config panel added");
		} catch(Exception e) {
			// No UI could be found, create a simple UI stating that
			logger.trace("Error caught: ", e.msg);
			logger.warning("[", info.id, "] No config UI found.");

			configPanel = new Box(GtkOrientation.VERTICAL, 5);
			Label nothingFound = new Label("This plugin doesn't have a configuration menu.");
			PgAttributeList tempAttribs = nothingFound.getAttributes() is null ? new PgAttributeList() : nothingFound.getAttributes();
			tempAttribs.change(uiItalic());
			tempAttribs.change(uiGrey());
			nothingFound.setAttributes(tempAttribs);
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
	logger.trace("headerInfo packed");

	topLevel.packStart(headerInfo, true, false, 0);
	topLevel.packStart(sep, true, false, 0);
	topLevel.packStart(configPanel, true, false, 0);
	logger.trace("topLevel packed");

	configBox.packStart(topLevel, true, false, 0);
	configBox.showAll();

	logger.trace("configBox packed");
}

// Populates a plugin info page
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
	piiAuthors.setLabel(formatArray(info.authors));
	piiURL.setLabel(url(info.url));
	piiType.setLabel("Official");
}

// Downloads a plugin to a temporary folder
public static void downloadPlugin(PluginInfo info) {
	gdk.Threads.threadsAddIdle(&downloadPlugin_idleFetch, null);
	spawn(&thread_downloadPlugin, cast(immutable)info);
	thread_downloadPlugin_completed = false;
}

shared bool thread_downloadPlugin_completed;
void thread_downloadPlugin(immutable PluginInfo info) {
	string archiveFile = info.id ~ ".tar.gz";
	string archivePath = buildPath(CDN_PATH, info.id, archiveFile);
	
	download(archivePath, buildPath(createTempPath(), "pc", archiveFile));

	thread_downloadPlugin_completed = true;
}

extern(C) nothrow int downloadPlugin_idleFetch(void* data) {
	try {
		if(thread_downloadPlugin_completed) return 0;
	} catch(Throwable t) return 0;

	return 1;
}

// Installs plugin in the local system
public static void installPlugin(PluginInfo info) {}

// Removes plugin from the local system
public static void uninstallPlugin(PluginInfo info) {}