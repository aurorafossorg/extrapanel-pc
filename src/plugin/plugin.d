module plugin.plugin;

import std.json;
import util.paths;
import std.path;
import std.file;

import util.logger;

/**
 *	plugin.d - General plugin code for the app
 */

// Type of content to show
enum Type {
	Plugin,
	Pack,
	Installed
}

// Class holding all plugin important info
class PluginInfo {
	// Constructor with path to load from meta.json
	this(string id) {
		JSONValue j = parseJSON(readText(buildPath(pluginRootPath(id), "meta.json")));

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