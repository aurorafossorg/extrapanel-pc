module extrapanel.core.util.paths;

// STD
public import std.path;
import std.file;

/**
 *	paths.d - Utility methods for path building
 */

public immutable string CONFIG_PATH = "extrapanel.cfg";
public immutable string LOCK_PATH = "daemon.lock";
public immutable string LOG_PATH = "daemon.log";

version(unittest)
	public immutable string APP_BASE_PATH = ".extrapanel-temp-config";
else
	public immutable string APP_BASE_PATH = "extrapanel";

version(unittest) {
	public immutable string EXAMPLE_FILES_PATH = buildPath("tools", "example-files");
	public immutable string EXAMPLE_PLUGIN_PATH = EXAMPLE_FILES_PATH.buildPath("example-plugin-installed");

	public immutable string EXAMPLE_BOOTSTRAP_CONFIG = "extrapanel-bootstrap-config.cfg";
}

public immutable string PID_PATH = "extrapanel-daemon.pid";
public immutable string PLUGIN_BASE_PATH = "plugins";

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

// Creates base paths for the app
public static void createAppPaths() {
	string root = getConfigRootDir();
	if(!exists(root.buildPath(APP_BASE_PATH)))
		mkdir(root.buildPath(APP_BASE_PATH));

	if(!exists(root.buildPath(APP_BASE_PATH, PLUGIN_BASE_PATH)))
		mkdir(root.buildPath(APP_BASE_PATH, PLUGIN_BASE_PATH));
}

// Creates temporary work dir
public static string createTempPath() {
	string root = tempDir.buildPath(APP_BASE_PATH);
	if(!exists(root))
		mkdir(root);
	
	if(!exists(root.buildPath("pc")))
		mkdir(root.buildPath("pc"));

	return root;
}

// Returns the path for the app config
public static string appConfigPath() {
	return buildPath(getConfigRootDir(), APP_BASE_PATH);
}

// Returns the installed plugin path based on it's id
public static string pluginRootPath(string pluginID = null) {
	if(pluginID == null)
		return buildPath(appConfigPath(), PLUGIN_BASE_PATH);
	else
		return buildPath(appConfigPath(), PLUGIN_BASE_PATH, pluginID ~ dirSeparator);
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