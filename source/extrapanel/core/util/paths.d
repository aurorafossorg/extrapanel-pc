module extrapanel.core.util.paths;

// STD
public import std.path;
public import std.file;

/**
 *	paths.d - Utility methods for path building
 */

/// The file name for the config file.
public immutable string CONFIG_PATH = "extrapanel.cfg";

/// The file name for the daemon lock file.
public immutable string LOCK_PATH = "daemon.lock";

/// The file name for the daemon log file.
public immutable string LOG_PATH = "daemon.log";

version(unittest)
	/// The folder where the config is stored. (for unittesting)
	public immutable string APP_BASE_PATH = ".extrapanel-temp-config";
else
	/// The folder where the config is stored.
	public immutable string APP_BASE_PATH = "extrapanel";

version(unittest) {
	/// The file path for the example files.
	public immutable string EXAMPLE_FILES_PATH = buildPath("tools", "example-files");

	/// The file path for the example plugin.
	public immutable string EXAMPLE_PLUGIN_PATH = EXAMPLE_FILES_PATH.buildPath("example-plugin-installed");

	/// The file path for the example configuration.
	public immutable string EXAMPLE_BOOTSTRAP_CONFIG = "extrapanel-bootstrap-config.cfg";
}

/// The file name for the PID file.
public immutable string PID_PATH = "extrapanel-daemon.pid";

/// The file path for the base plugins folder.
public immutable string PLUGIN_BASE_PATH = "plugins";

/// The URL path for the remote CDN where official plugins are stored.
public immutable string CDN_PATH = "https://dl.aurorafoss.org/aurorafoss/pub/releases/xpanel-plugins/";

private static string getConfigRootDir() {
	version(unittest) {
		return buildPath(getcwd());
	}
	else {
		version (Windows) {
			return "null";
		}
		version(OSX) {
			return "null";
		}
		version(linux) {
			return buildPath(expandTilde("~"), ".config");
		}
	}
}

/// Creates the base paths for the app to store it's config.
public static void createAppPaths() {
	string root = getConfigRootDir();
	if(!exists(root.buildPath(APP_BASE_PATH)))
		mkdir(root.buildPath(APP_BASE_PATH));

	if(!exists(root.buildPath(APP_BASE_PATH, PLUGIN_BASE_PATH)))
		mkdir(root.buildPath(APP_BASE_PATH, PLUGIN_BASE_PATH));
}

/// Creates a temporary path for the app.
public static string createTempPath() {
	string root = tempDir.buildPath(APP_BASE_PATH);
	if(!exists(root))
		mkdir(root);

	if(!exists(root.buildPath("pc")))
		mkdir(root.buildPath("pc"));

	return root;
}

/**
 * Returns the path for the app config.
 *
 * Returns: A file path of the app's config folder.
 */
public static string appConfigPath() {
	return buildPath(getConfigRootDir(), APP_BASE_PATH);
}

/**
 * Returns either the installed plugin path's or the root path for plugins.
 *
 * Params:
 *		pluginID = the id of a plugin. Can be null to get the root plugin path only.
 *
 * Returns: File path with the plugin's config folder, if pluginID was supplied; Otherwise, file path with the root folder for plugins.
 */
public static string pluginRootPath(string pluginID = null) {
	if(pluginID == null)
		return buildPath(appConfigPath(), PLUGIN_BASE_PATH);
	else
		return buildPath(appConfigPath(), PLUGIN_BASE_PATH, pluginID ~ dirSeparator);
}

public static void mkdir(string path) {
	if(!exists(path)) std.file.mkdir(path);
}

@("Paths: Root config path exists")
unittest {
	string rootPath = getConfigRootDir();
	assert(exists(rootPath));
}

@("Paths: Base app paths exist")
unittest {
	createAppPaths();
	string rootPath = getConfigRootDir();

	assert(rootPath.exists);
	assert(rootPath.buildPath(APP_BASE_PATH).exists);
	assert(rootPath.buildPath(APP_BASE_PATH, PLUGIN_BASE_PATH).exists);

	assert(appConfigPath().exists);
	assert(appConfigPath() == rootPath.buildPath(APP_BASE_PATH));
}

@("Paths: Temp path exist")
unittest {
	immutable string tmpDir = createTempPath();

	assert(tmpDir.exists);
	assert(tmpDir.buildPath("pc").exists);
}

@("Paths: Plugin paths exist")
unittest {
	immutable string rootPluginPath = pluginRootPath();
	assert(rootPluginPath.exists);

	immutable string nullPluginPath = pluginRootPath("null");
	assert(!nullPluginPath.exists);
	assert(rootPluginPath != nullPluginPath);
}
