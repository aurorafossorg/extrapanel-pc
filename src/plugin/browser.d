module extrapanel.browser;

import std.path;
import std.file;

import plugin.plugin;
import util.paths;
import util.logger;
import util.util;

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

import pango.PgAttributeList;
import pango.PgAttribute;

import std.json;

/**
 *	browser.d - Methods responsible for managing plugins and constructing GTK elements
 */

enum Template {
	Complete,		// Complete plugin description, for info page
	ListElement,	// Element of a TreeView list
	ConfigElement	// Element for the config page
}

// Methods that populate GTK objects with plugin info

// Populates the parent TreeView of plugins/packs/installed with all the plugins
public static void retrieveList(string url, Type type, GtkTreeView parent, Builder builder) {
	// Retrive the metadata.json from the url
}

// Gets the list of currently installed plugins
public string[] getInstalledPlugins() {
	string[] ids;
	string pluginRootPath = buildPath(appConfigPath(), "plugins");
	foreach(string id; dirEntries(pluginRootPath, SpanMode.shallow)) {
		ids ~= id;
	}

	return ids;
}

// Populates GTK elements with the info of plugins depending on the type of info to display
public static void parseInfo(PluginInfo info, Template temp, Widget parent, Builder builder, Window window) {
	switch(temp) {
		case Template.Complete:

			break;
		case Template.ListElement:

			break;
		case Template.ConfigElement:
			Box configBox = cast(Box) parent;

			// Creates the top level
			VBox topLevel = new VBox(false, 5);
			topLevel.setMarginTop(MARGIN_DEFAULT);
			topLevel.setMarginBottom(MARGIN_DEFAULT * 3);
			topLevel.setMarginStart(MARGIN_DEFAULT);
			topLevel.setMarginEnd(MARGIN_DEFAULT);

			// Creates the header info
			HBox headerInfo = new HBox(false, 5);
			headerInfo.setHomogeneous(false);
			headerInfo.setHalign(GtkAlign.START);

			// Create a separator
			Separator sep = new Separator(GtkOrientation.HORIZONTAL);

			// Adds elements to the header: the plugin's logo and title
			// Logo
			string logoPath = buildPath(pluginRootPath(info.id), info.icon);
			Image logo = new Image(logoPath);

			// Title
			Label title = new Label(info.name);
			PgAttributeList attribs = title.getAttributes() is null ? new PgAttributeList() : title.getAttributes();
			attribs.change(PgAttribute.weightNew(PangoWeight.BOLD));
			title.setAttributes(attribs);

			Box configPanel;
			// Loads the configuration menu, if it exists
			try {
				builder.addFromFile(buildPath(pluginRootPath(info.id), "configMenu.ui"));
				configPanel = cast(Box) builder.getObject("configWindow");
				logger.trace(configPanel);
				logger.trace("Config panel added");
			} catch(Exception e) {
				logger.warning("[", info.id, "] No config UI found.");

				configPanel = new Box(GtkOrientation.VERTICAL, 5);
				Label nothingFound = new Label("This plugin doesn't have a configuration menu.");
				PgAttributeList tempAttribs = nothingFound.getAttributes() is null ? new PgAttributeList() : nothingFound.getAttributes();
				tempAttribs.change(PgAttribute.styleNew(PangoStyle.ITALIC));
				tempAttribs.change(PgAttribute.foregroundNew(0xaaaa, 0xaaaa, 0xaaaa));
				nothingFound.setAttributes(tempAttribs);
				configPanel.packStart(nothingFound, true, false, 0);
			}

			// Packs all the elements
			headerInfo.packStart(logo, true, false, 0);
			headerInfo.packStart(title, true, false, 0);
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

// Installs plugin in the local system
public static void addPlugin(PluginInfo info) {}

// Removes plugin from the local system
public static void removePlugin(PluginInfo info) {}