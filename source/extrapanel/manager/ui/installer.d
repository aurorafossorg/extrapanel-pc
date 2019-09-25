module extrapanel.manager.ui.installer;

// Archive
import archive.targz;

// Core
import core.exception;
import core.thread;

// Extra Panel
import extrapanel.core.plugin.info;
import extrapanel.core.util.formatter;
import extrapanel.core.util.logger;
import extrapanel.core.util.paths;
import extrapanel.core.util.util;

// GDK
import gdk.Cursor;
import gdk.Threads;

// GIO
import gio.Application : GApplication = Application;

// GTK
import gtk.Application;
import gtk.Assistant;
import gtk.Box;
import gtk.Builder;
import gtk.Image;
import gtk.Label;
import gtk.Spinner;
import gtk.Stack;
import gtk.Switch;
import gtk.TextBuffer;
import gtk.TextIter;
import gtk.Widget;

// STD
import std.algorithm.mutation;
import std.algorithm.searching;
import std.concurrency;
import std.file;
import std.json;
import std.stdio;
import std.string;
import std.process;

/**
 *	installer.d - UI for the installer wizard
 */

enum Pages : int {
	INTRO,
	LUA_DEPS,
	LUA_DEPS_PROGRESS,
	ROOT_REQUEST,
	PLUGIN_INSTALL,
	COMPLETED
}

enum PluginType : int {
	OFFICIAL,
	COMMUNITY,
	UNTRUSTED
}

static InstallerUI app;

/// Main application
class InstallerUI : Application
{
public:
	/// Constructor
	this(string inputPath)
	{
		this.inputPath = inputPath;
		this.pluginMeta = parseJSON(readText(buildPath(inputPath, "meta.json")));

		// Loads configuration and sets callbacks
		ApplicationFlags flags = ApplicationFlags.FLAGS_NONE;
		super("org.aurorafoss.extrapanel.manager.installer", flags);
		this.wizard = null;
		this.addOnActivate(&onAppActivate);
	}

	// App activated
	void onAppActivate(GApplication app) {
		trace("Activate App Signal");
		// Detect if there are other instances of this app running
		if (!app.getIsRemote() && wizard is null)
		{
			// Loads the UI files
			trace("Primary instance, loading UI...");
			builder = new Builder();
			if(!builder.addFromResource("/org/aurorafoss/extrapanel/ui/installer.ui"))
			{
				critical("Window resource cannot be found");
				return;
			}

			// Setup the app
			initElements();
			updateElements();
		} else {
			trace("Another instance exists, taking control...");
		}

		// Show
		this.wizard.present();
	}

	// Plugin information
	immutable JSONValue pluginMeta;
	string inputPath;
	string[] neededLuaDeps;

	// Return state
	int returnState;

	// Constructor
	Builder builder;

	// Assistant
	Assistant wizard;

	// Pages
	Box pageIntro;
	Box pageLuaDeps;
	Box pageLuaDepsProgress;
		Label pLuaCurrentDep;
		Spinner pLuaSpinner;
	Box pageRootRequest;
		Stack pRootPluginType;
		Switch pRootConsent;
	Box pagePluginInstall;
		Label pPluginLabel;
		Spinner pPluginSpinner;
	Box pageCompleted;

	// Text Buffers
	TextBuffer luaInstallTextBuffer, pluginInstallTextBuffer;

	// Cursor
	Cursor loadingCursor;

	// Inits the builder defined elements
	void initElements()
	{
		// Top level
		wizard = cast(Assistant) builder.getObject("assistant");
		wizard.setApplication(this);

		// Assistant pages
		pageIntro = cast(Box) builder.getObject("pageIntro");
		pageLuaDeps = cast(Box) builder.getObject("pageLuaDeps");
		pageLuaDepsProgress = cast(Box) builder.getObject("pageLuaDepsProgress");
		pLuaCurrentDep = cast(Label) builder.getObject("pLuaCurrentDep");
		pLuaSpinner = cast(Spinner) builder.getObject("pLuaSpinner");
		pageRootRequest = cast(Box) builder.getObject("pageRootRequest");
		pRootPluginType = cast(Stack) builder.getObject("pRootPluginType");
		pRootConsent = cast(Switch) builder.getObject("pRootConsent");
		pagePluginInstall = cast(Box) builder.getObject("pagePluginInstall");
		pPluginLabel = cast(Label) builder.getObject("pPluginLabel");
		pPluginSpinner = cast(Spinner) builder.getObject("pPluginSpinner");
		pageCompleted = cast(Box) builder.getObject("pageCompleted");

		// Text buffers
		luaInstallTextBuffer = cast(TextBuffer) builder.getObject("luaInstallTextBuffer");
		pluginInstallTextBuffer = cast(TextBuffer) builder.getObject("pluginInstallTextBuffer");
	}

	void updateElements()
	{
		wizard.addOnCancel(&wizardOnCancel);
		wizard.addOnClose(&wizardOnClose);

		pageIntro.addOnMap(&onIntroPage);
		pageLuaDeps.addOnMap(&onLuaDepsPage);
		pageLuaDepsProgress.addOnMap(&onLuaDepsProgressPage);
		pageRootRequest.addOnMap(&onRootRequestPage);
		pagePluginInstall.addOnMap(&onPluginInstallPage);
		pageCompleted.addOnMap(&onCompletedPage);

		pRootConsent.addOnStateSet(&rootConsentToggle);

		loadingCursor = new Cursor(wizard.getDisplay(), GdkCursorType.WATCH);
	}

	void wizardOnCancel(Assistant a) {
		trace("Closed");
		returnState = -1;
		this.wizard.destroy();
	}

	void wizardOnClose(Assistant a) {
		trace("Finished");
		returnState = 0;
		this.wizard.destroy();
	}

	void onIntroPage(Widget w) {
		parseInfo(new PluginInfo(pluginMeta));
	}

	void onLuaDepsPage(Widget w) {
		try {
			// Obtaines the needed Lua dependencies
			auto luaDeps = pluginMeta["install-steps"].object["lua-deps"].arrayNoRef;

			// Obtains the list of installed dependencies and finds which ones need to be installed
			auto luaRocksList = execute(["luarocks", "list"]);
			foreach(dep; luaDeps) {
				if(!canFind(luaRocksList.output, dep.str))
					neededLuaDeps ~= dep.str;
			}

			// If the dependencies are installed move on
			if(neededLuaDeps.empty) {
				wizard.setCurrentPage(Pages.ROOT_REQUEST);
				return;
			}

			Label pLuaDepsLabel = cast(Label) builder.getObject("pLuaDepsLabel");
			string labelText;
			foreach(dep; neededLuaDeps) {
				labelText ~= "- " ~ bold(dep) ~ "\n";
			}

			labelText = strip(labelText);
			pLuaDepsLabel.setMarkup(labelText);

		} catch(JSONException e) {
			wizard.setCurrentPage(Pages.ROOT_REQUEST);
		}
	}

	void onLuaDepsProgressPage(Widget w) {
		installLuaDep();
	}

	bool rootConsentToggle(bool toggle, Switch s) {
		wizard.setPageComplete(wizard.getNthPage(Pages.ROOT_REQUEST), s.getActive());
		s.setState(toggle);
		return true;
	}

	void onRootRequestPage(Widget w) {
		try {
			bool needsRoot = pluginMeta["install-steps"].object["needs-root"].boolean;

			if(!needsRoot) {
				wizard.setCurrentPage(Pages.PLUGIN_INSTALL);
				return;
			} else {
				// Chooses the right description for plugin type
			}

		} catch(JSONException e) {
			wizard.setCurrentPage(Pages.PLUGIN_INSTALL);
		} catch(RangeError e) {
			wizard.setCurrentPage(Pages.PLUGIN_INSTALL);
		}
	}

	void onPluginInstallPage(Widget w) {
		string archiveName = buildPath(inputPath, pluginMeta["id"].str ~ ".tar.gz");
		trace("Archive: ", archiveName);
		gdk.Threads.threadsAddIdle(&pluginInstall_idleFetch, null);
		spawn(&pluginInstall, pluginMeta["id"].str, archiveName);
		pluginInstalling = true;
	}

	void onCompletedPage(Widget w) {

	}

	void parseInfo(PluginInfo info) {
		Image pihIcon = cast(Image) builder.getObject("pihIcon");
		Label pihTitle = cast(Label) builder.getObject("pihTitle");
		Label pihDescription = cast(Label) builder.getObject("pihDescription");
		Label piiID = cast(Label) builder.getObject("piiID");
		Label piiVersion = cast(Label) builder.getObject("piiVersion");
		Label piiAuthors = cast(Label) builder.getObject("piiAuthors");
		Label piiURL = cast(Label) builder.getObject("piiURL");
		Label piiType = cast(Label) builder.getObject("piiType");

		string logoPath = buildPath(inputPath, "icon.png");
		pihIcon.setFromFile(logoPath);
		pihTitle.setLabel(info.name);
		pihDescription.setLabel(info.description);

		piiID.setLabel(info.id);
		piiVersion.setLabel(info.strVersion);
		piiAuthors.setLabel(formatArray(info.authors));
		piiURL.setLabel(url(info.url));
		piiType.setLabel("Official");
	}

	void appendLuaInstallTextBuffer(string line) {
		TextIter end_iter;
		luaInstallTextBuffer.getEndIter(end_iter);
		luaInstallTextBuffer.insert(end_iter, line);
	}

	void appendPluginInstallTextBuffer(string line) {
		TextIter end_iter;
		pluginInstallTextBuffer.getEndIter(end_iter);
		pluginInstallTextBuffer.insert(end_iter, line ~ "\n");
	}

	void installLuaDep() {
		if(!neededLuaDeps.empty) {
			trace("Installing a Lua dependency...");
			immutable string luaDep = neededLuaDeps[0];
			neededLuaDeps = neededLuaDeps.remove(0);

			pLuaCurrentDep.setMarkup(bold(luaDep));
			gdk.Threads.threadsAddIdle(&luaDepInstall_idleFetch, null);
			spawn(&luaDepInstall, luaDep);
			luaDepInstalling = true;
		} else {
			pLuaCurrentDep.setMarkup(italic("Completed"));
			pLuaSpinner.stop();
			wizard.setPageComplete(wizard.getNthPage(Pages.LUA_DEPS_PROGRESS), true);
		}
	}

	void completedPluginInstallation() {
		pPluginLabel.setMarkup(italic("Completed"));
		pPluginSpinner.stop();
		wizard.setPageComplete(wizard.getNthPage(Pages.PLUGIN_INSTALL), true);
	}
}

void luaDepInstall(string luaDep) {
	string[] command = ["luarocks", "install", luaDep, "--local"];
	writeln("Command generated: ", command);
	auto pipe = pipeProcess(command, Redirect.stdout);

	while(!tryWait(pipe.pid).terminated) {
		immutable string line = pipe.stdout.readln;
		ownerTid.send(line);
	}
	writeln("Command finished...");
	luaDepInstalling = false;
}

shared bool luaDepInstalling = false;
extern(C) nothrow int luaDepInstall_idleFetch(void* data) {
	try {
		receiveTimeout(dur!("msecs")(10), (string output) {
			app.appendLuaInstallTextBuffer(output);
		});
		if(!luaDepInstalling) {
			app.appendLuaInstallTextBuffer("\n-------\n");
			app.installLuaDep();
			return 0;
		}
	} catch(Throwable t) return 0;

	return 1;
}

void pluginInstall(string pluginId, string archiveName) {
	writeln("Creating archive...");
	TarGzArchive archive = new TarGzArchive(read(archiveName));
	string outputPath = pluginRootPath();
	try {
		mkdir(outputPath);
	} catch(Exception e) {}
	writeln("Made output dir on \"", outputPath, "\"");

	writeln("Archive found, extracting it...");
	foreach(object; archive.members) {
		if(object.isDirectory()) {
			// Directory
			archive.Directory dir = cast(archive.Directory)object;
			writeln("Making folder \"" ~ dir.path() ~ "\"...");
			ownerTid.send("Making folder \"" ~ dir.path() ~ "\"...");
			try {
				mkdir(buildPath(outputPath, dir.path()));
			} catch(Exception e) {}
		} else {
			// File
			archive.File file = cast(archive.File)object;
			writeln("Copying file \"" ~ file.path() ~ "\"...");
			ownerTid.send("Copying file \"" ~ file.path() ~ "\"...");
			try {
				std.file.write(buildPath(outputPath, file.path()), file.data());
			} catch(Exception e) {}
		}
	}

	ownerTid.send("Completed");
	writeln("Finished plugin installation");
}

shared bool pluginInstalling = false;
extern(C) nothrow int pluginInstall_idleFetch(void* data) {
	try {
		receive((string output) {
			app.appendPluginInstallTextBuffer(output);
			if(output == "Completed") {
				app.completedPluginInstallation();
				pluginInstalling = false;
			}
		});
		if(!pluginInstalling) {
			return 0;
		}
	} catch(Throwable t) return 0;

	return 1;
}