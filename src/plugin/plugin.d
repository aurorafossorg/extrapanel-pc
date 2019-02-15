module extrapanel.plugin;

public enum PluginType {
	Official,
	Community,
	Other
}

class PluginInfo {
	immutable string id, name, description, icon, strVersion;
	immutable string[] authors;
	immutable PluginType type;
}