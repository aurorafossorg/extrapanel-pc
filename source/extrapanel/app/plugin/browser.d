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

enum Template {
	Complete,		// Complete plugin description, for info page
	ListElement,	// Element of a TreeView list
	ConfigElement	// Element for the config page
}

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
	Pixbuf logo = new Pixbuf(buildPath(createTempPath(), "pc", pluginInfo.id ~ "-icon.png"));
	bool installed = false;
	foreach(id; getInstalledPlugins()) {
		if(canFind(id, pluginInfo.id)) {
			installed = true;
			break;
		}
	}
	string text = bold(pluginInfo.name) ~ "\n" ~ pluginInfo.description;

	store.setValue(iterator, ListStoreColumns.Installed, installed);
	store.setValue(iterator, ListStoreColumns.Logo, logo);
	store.setValue(iterator, ListStoreColumns.Text, text);
	store.setValue(iterator, ListStoreColumns.Version, pluginInfo.strVersion);
	store.setValue(iterator, ListStoreColumns.Type, "Official");
}

private static string[] installedPluginsIds;

// Gets the list of currently installed plugins
public static string[] getInstalledPlugins(bool refresh = false) {
	if(installedPluginsIds.empty && !refresh) {
		string pluginRootPath = buildPath(appConfigPath(), "plugins");
		foreach(string id; dirEntries(pluginRootPath, SpanMode.shallow)) {
			installedPluginsIds ~= id;
		}
	}

	return installedPluginsIds;
}

public static ScriptRunner runner = null;
// Populates GTK elements with the info of plugins depending on the type of info to display
public static void parseInfo(PluginInfo info, Template temp, Widget parent, Builder builder) {
	switch(temp) {
		case Template.Complete:
			Image pihIcon = cast(Image) builder.getObject("pihIcon");
			Label pihTitle = cast(Label) builder.getObject("pihTitle");
			Label pihDescription = cast(Label) builder.getObject("pihDescription");
			Label piiID = cast(Label) builder.getObject("piiID");
			Label piiVersion = cast(Label) builder.getObject("piiVersion");
			Label piiAuthors = cast(Label) builder.getObject("piiAuthors");
			Label piiURL = cast(Label) builder.getObject("piiURL");
			Label piiType = cast(Label) builder.getObject("piiType");

			string logoPath = buildPath(pluginRootPath(info.id), info.icon);
			pihIcon.setFromFile(logoPath);
			pihTitle.setLabel(info.name);
			pihDescription.setLabel(info.description);

			piiID.setLabel(info.id);
			piiVersion.setLabel(info.strVersion);
			piiAuthors.setLabel(formatArray(info.authors));
			piiURL.setLabel(makeURL(info.url));
			piiType.setLabel("Official");
			break;
		case Template.ListElement:
			
			break;
		case Template.ConfigElement:
			Box configBox = cast(Box) parent;

			ScriptRunner scriptRunner = ScriptRunner.getInstance();

			// Creates the top level
			VBox topLevel = new VBox(false, 5);
			topLevel.setMarginTop(MARGIN_DEFAULT);
			topLevel.setMarginBottom(MARGIN_DEFAULT * 3);
			topLevel.setMarginStart(MARGIN_DEFAULT);
			topLevel.setMarginEnd(MARGIN_DEFAULT);

			// Creates the header info
			HBox headerInfo = new HBox(false, 5);
			headerInfo.setHomogeneous(false);
			//headerInfo.setHalign(GtkAlign.START);

			// Create a separator
			Separator sep = new Separator(GtkOrientation.HORIZONTAL);

			// Adds elements to the header: the plugin's logo, title and info button
			// Logo
			string logoPath = buildPath(pluginRootPath(info.id), info.icon);
			Image logo = new Image(logoPath);

			// Title
			Label title = new Label(info.name);
			PgAttributeList attribs = title.getAttributes() is null ? new PgAttributeList() : title.getAttributes();
			attribs.change(PgAttribute.weightNew(PangoWeight.BOLD));
			title.setAttributes(attribs);

			// Info Button
			HBox buttonBox = new HBox(true, 2);
			buttonBox.setHexpand(true);
			buttonBox.setHalign(GtkAlign.END);

			Button btInfo = new Button("Info");
			btInfo.setHalign(GtkAlign.CENTER);
			btInfo.setValign(GtkAlign.CENTER);
			xPanelApp.pluginInfoIds[btInfo] = info;
			btInfo.addOnClicked(&xPanelApp.openPluginInfo);

			Button btUninstall = new Button("Uninstall");
			btUninstall.setHalign(GtkAlign.CENTER);
			btUninstall.setValign(GtkAlign.CENTER);

			Box configPanel;
			// Loads the configuration menu, if it exists
			try {
				scriptRunner.loadPlugin(info.id, ScriptType.CONFIG_SCRIPT);
				configPanel = new Box(scriptRunner.setupConfigMenu(info.id));
				logger.trace(configPanel);
			} catch(FileNotFoundException e) {
				try {
					builder.addFromFile(buildPath(pluginRootPath(info.id), "configMenu.ui"));
					logger.trace(info.id ~ "_configWindow");
					configPanel = cast(Box) builder.getObject(info.id ~ "_configWindow");
					logger.trace("Config panel added");
				} catch(Exception e) {
					logger.trace("Error caught: ", e.msg);
					logger.warning("[", info.id, "] No config UI found.");

					configPanel = new Box(GtkOrientation.VERTICAL, 5);
					Label nothingFound = new Label("This plugin doesn't have a configuration menu.");
					PgAttributeList tempAttribs = nothingFound.getAttributes() is null ? new PgAttributeList() : nothingFound.getAttributes();
					tempAttribs.change(PgAttribute.styleNew(PangoStyle.ITALIC));
					tempAttribs.change(PgAttribute.foregroundNew(0xaaaa, 0xaaaa, 0xaaaa));
					nothingFound.setAttributes(tempAttribs);
					configPanel.packStart(nothingFound, true, false, 0);
				}
			}

			configPanel.setMarginLeft(10);
			configPanel.setMarginRight(10);
			configPanel.setMarginBottom(10);

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
			break;
		default:
			break;
	}
}

// Downloads a plugin to a temporary folder
public static void downloadPlugin(PluginInfo info) {
	gdk.Threads.threadsAddIdle(&downloadPlugin_idleFetch, null);
	spawn(&thread_downloadPlugin, cast(immutable)info);
	thread_downloadPlugin_completed = true;
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