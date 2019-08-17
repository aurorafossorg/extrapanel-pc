module extrapanel.core.plugin.info;

import std.json;
import std.path;
import std.file;

import extrapanel.core.util.logger;
import extrapanel.core.util.paths;

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

	string[] getInstalledPlugins(bool refresh = false) {
		if(!plugins.length || !refresh)
			populateInstalledPlugins();

		return plugins.keys;
	}

	PluginInfo getPlugin(string id) {
		return plugins[id];
	}

	bool isPluginInstalled(string id) {
		return getPlugin(id) !is null;
	}

private:
	this() {
		populateInstalledPlugins();
	}

	~this() {}

	void populateInstalledPlugins() {
		plugins.clear();

		foreach(string id; dirEntries(pluginRootPath(), SpanMode.shallow)) {
			plugins[id] = new PluginInfo(id);
		}

		PluginInfo[string] oldPlugins = plugins;
		plugins.rehash;
	}

	PluginInfo[string] plugins;

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

		logger.trace(this.id);
		logger.trace(this.name);
		logger.trace(this.description);
		logger.trace(this.icon);
		logger.trace(this.strVersion);
		logger.trace(this.url);
	}

	immutable string id, name, description, icon, strVersion, url, repoUrl;
	JSONValue[] authors;
}