module extrapanel.core.plugin.info;

// Extra Panel
import extrapanel.core.util.logger;
import extrapanel.core.util.paths;

// GTK
import gtk.Widget;

// STD
import std.file;
import std.json;

/**
 *	plugin.d - General plugin code for the app
 */

// Singleton to manage current plugins
class PluginManager {
public:
	static PluginManager getInstance() {
		if(pluginManager is null)
			pluginManager = new PluginManager();

		return pluginManager;
	}

	PluginInfo[] getInstalledPlugins(bool refresh = false) {
		if(!plugins.length || !refresh)
			populateInstalledPlugins();

		return plugins.values;
	}

	PluginInfo getPlugin(string id) {
		return plugins[id];
	}

	bool isPluginInstalled(PluginInfo pluginInfo) {
		return (pluginInfo.id in plugins) !is null;
	}

	void mapWidgetWithPlugin(PluginInfo pluginInfo, Widget widget) {
		mappedWidgets[widget] = pluginInfo;
	}

	PluginInfo getMappedPlugin(Widget widget) {
		return mappedWidgets[widget];
	}

private:
	this() {
		populateInstalledPlugins();
	}

	~this() {}

	void populateInstalledPlugins() {
		plugins.clear();

		foreach(string path; dirEntries(pluginRootPath(), SpanMode.shallow)) {
			PluginInfo pluginInfo = new PluginInfo(path);
			plugins[pluginInfo.id] = pluginInfo;
		}

		plugins.rehash;
	}

	PluginInfo[string] plugins;
	PluginInfo[Widget] mappedWidgets;

	static PluginManager pluginManager;
}

// Class holding all plugin important info
class PluginInfo {
	// Constructor with path to load from meta.json
	this(string id) {
		JSONValue j = parseJSON(readText(buildPath(pluginRootPath(id), "meta.json")));
		this(j);
	}

	this(JSONValue j) {
		// Required fields
		this.id = j["id"].str;
		this.name = j["name"].str;
		this.description = j["description"].str;
		this.icon = j["icon"].str;
		this.strVersion = j["version"].str;
		this.url = j["url"].str;

		// Optional fields
		this.authors = "authors" in j ? j["authors"].arrayNoRef : null;
		this.repoUrl = "repoUrl" in j ? j["repoUrl"].str : "unspecified";

		trace(this.id);
		trace(this.name);
		trace(this.description);
		trace(this.icon);
		trace(this.strVersion);
		trace(this.url);
	}

	immutable string id, name, description, icon, strVersion, url, repoUrl;
	JSONValue[] authors;
}

@("Plugin: read info from a JSON file")
unittest {
	createAppPaths();
	string pluginRoot = pluginRootPath("plugin-example");

	// Copy the CFG file to plugin path
	if(!exists(pluginRoot)) mkdir(pluginRoot);
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "meta.json"), buildPath(pluginRoot, "meta.json"));

	// Load example plugin meta info
	PluginInfo info = new PluginInfo("plugin-example");

	// Assert required fields exist
	assert(info.id == "plugin-example");
	assert(info.name == "Example Plugin");
	assert(info.description == "Example plugin for unittesting");
	assert(info.icon == "assets/icon.png");
	assert(info.strVersion == "0.0.1");
	assert(info.url == "null");

	// Assert optional fields exist even not in the file
	import extrapanel.core.util.util : formatArray;
	assert(formatArray(info.authors) == "Ev1lbl0w"); // This exists in the file
	assert(info.repoUrl == "unspecified"); // This doesn't exist in the file
}