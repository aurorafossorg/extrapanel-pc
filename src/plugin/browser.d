module extrapanel.browser;

import std.path;
import std.file;

import plugin.plugin;
import util.paths;
import util.logger;
import util.util;
import util.exception;

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

import pango.PgAttributeList;
import pango.PgAttribute;

import riverd.lua.statfun;
import riverd.lua.types;

import std.json;
import std.string;

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

ScriptRunner runner = null;

// Populates GTK elements with the info of plugins depending on the type of info to display
public static void parseInfo(PluginInfo info, Template temp, Widget parent, Builder builder, Window window) {
	switch(temp) {
		case Template.Complete:

			break;
		case Template.ListElement:

			break;
		case Template.ConfigElement:
			Box configBox = cast(Box) parent;

			if(runner is null)
				runner = new ScriptRunner();

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
			Button btInfo = new Button("Info");
			btInfo.setHalign(GtkAlign.END);

			Box configPanel;
			// Loads the configuration menu, if it exists
			try {
				/*builder.addFromFile(buildPath(pluginRootPath(info.id), "configMenu.ui"));
				logger.trace(info.id ~ "_configWindow");
				Box configPanelOld = cast(Box) builder.getObject(info.id ~ "_configWindow");
				logger.trace(configPanelOld);
				logger.trace("Config panel added");*/
				configPanel = new Box(runner.run(pluginRootPath(info.id)));
				logger.trace(configPanel);
			} catch(FileNotFoundException e) {
				builder.addFromFile(buildPath(pluginRootPath(info.id), "configMenu.ui"));
				logger.trace(info.id ~ "_configWindow");
				Box configPanelOld = cast(Box) builder.getObject(info.id ~ "_configWindow");
				logger.trace(configPanelOld);
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
			// Packs all the elements
			headerInfo.packStart(logo, true, false, 0);
			headerInfo.packStart(title, true, false, 0);
			//headerInfo.packStart(btInfo, true, false, 0);
			logger.trace("headerInfo packed");

			topLevel.packStart(headerInfo, true, false, 0);
			topLevel.packStart(sep, true, false, 0);
			logger.trace("about to crash");
			topLevel.packStart(configPanel, true, false, 0);
			logger.trace("topLevel packed");

			configBox.packStart(topLevel, true, false, 0);
			configBox.showAll();
			// Runs ui script

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

public class ScriptRunner {
public:
	GtkBox* run(string script) {
		// Create Lua state
		lua_State* luaState = luaL_newstate();
		luaL_openlibs(luaState);
		logger.trace("[", script, "] Lua state created");

		// Loads Lua script and calls connect()
		string path = buildPath(script, "ui.lua");
		logger.trace("path: ", path);
		if(!exists(path)) {
			lua_close(luaState);
			throw new FileNotFoundException(path);
		}

		if(luaL_loadfile(luaState, path.toStringz)) {
			logger.critical("[", script, "] Failed to load Lua script for ", script, "! Error: ", lua_tostring(luaState, -1).fromStringz);
			lua_close(luaState);
			throw new ScriptExecutionException(path, "main");
		}

		lua_pushstring(luaState, buildPath(script, "configMenu.ui").toStringz);
		if(lua_pcall(luaState, 1, LUA_MULTRET, 0)) {
			logger.critical("[", script, "] Failed to load Lua script for ", script, "! Error: ", lua_tostring(luaState, -1).fromStringz);
			lua_close(luaState);
			throw new ScriptExecutionException(path, "main");
		}

		logger.trace("1st dump:");
		stackDump(luaState);
		GtkBox* configBox = cast(GtkBox*) lua_touserdata(luaState, -1);

		logger.trace("[", script, "] Script loaded successfully");

		scripts[script] = luaState;
		return configBox;
	}

	~this() {
		foreach(luaState; scripts.values) {
			lua_close(luaState);
		}
	}

private:
	lua_State*[string] scripts;
}