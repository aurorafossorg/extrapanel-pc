module extrapanel.plugin;

class PluginInfo {
	this(string id, string name, string description, string icon, string strVersion, immutable string[] authors) {
		this.id = id;
		this.name = name;
		this.description = description;
		this.icon = icon;
		this.strVersion = strVersion;
		this.authors = authors;
	}

	immutable string id, name, description, icon, strVersion;
	immutable string[] authors;
}