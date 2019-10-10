module extrapanel.manager.ui.uninstaller;

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
import gtk.TextBuffer;
import gtk.TextIter;
import gtk.Widget;

// STD
import std.concurrency;
import std.file;
import std.json;
import std.stdio;

/**
 *	uninstaller.d - UI for the uninstaller wizard
 */

enum Pages : int {
	INTRO,
	PLUGIN_UNINSTALL,
	COMPLETED
}

enum PluginType : int {
	OFFICIAL,
	COMMUNITY,
	UNTRUSTED
}

/// The app instance for global access.
static UninstallerUI app;

/// Main application
class UninstallerUI : Application
{
public:
	/// Constructor
	this(string inputPath)
	{
		this.inputPath = pluginRootPath(inputPath);
		this.pluginMeta = parseJSON(readText(buildPath(this.inputPath, "meta.json")));

		// Loads configuration and sets callbacks
		ApplicationFlags flags = ApplicationFlags.FLAGS_NONE;
		super("org.aurorafoss.extrapanel.manager.uninstaller", flags);
		this.wizard = null;
		this.addOnActivate(&onAppActivate);
	}

	/// Return state of the app
	int returnState;

private:
	// App activated
	void onAppActivate(GApplication app) {
		trace("Activate App Signal");
		// Detect if there are other instances of this app running
		if (!app.getIsRemote() && wizard is null)
		{
			// Loads the UI files
			trace("Primary instance, loading UI...");
			builder = new Builder();
			if(!builder.addFromResource("/org/aurorafoss/extrapanel/ui/uninstaller.ui"))
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

	// Constructor
	Builder builder;

	// Assistant
	Assistant wizard;

	// Pages
	Box pageIntro;
	Box pagePluginUninstall;
		Label pPluginLabel;
		Spinner pPluginSpinner;
	Box pageCompleted;

	// Text Buffers
	TextBuffer pluginUninstallTextBuffer;

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
		pagePluginUninstall = cast(Box) builder.getObject("pagePluginUninstall");
		pPluginLabel = cast(Label) builder.getObject("pPluginLabel");
		pPluginSpinner = cast(Spinner) builder.getObject("pPluginSpinner");
		pageCompleted = cast(Box) builder.getObject("pageCompleted");

		// Text buffers
		pluginUninstallTextBuffer = cast(TextBuffer) builder.getObject("pluginUninstallTextBuffer");
	}

	void updateElements()
	{
		wizard.addOnCancel(&wizardOnCancel);
		wizard.addOnClose(&wizardOnClose);

		pageIntro.addOnMap(&onIntroPage);
		pagePluginUninstall.addOnMap(&onPluginUninstallPage);
		pageCompleted.addOnMap(&onCompletedPage);

		loadingCursor = new Cursor(wizard.getDisplay(), GdkCursorType.WATCH);
	}

	void wizardOnCancel(Assistant) {
		trace("Closed");
		returnState = -1;
		this.wizard.destroy();
	}

	void wizardOnClose(Assistant) {
		trace("Finished");
		returnState = 0;
		this.wizard.destroy();
	}

	void onIntroPage(Widget) {
		parseInfo(new PluginInfo(pluginMeta));
	}

	void onPluginUninstallPage(Widget) {
		gdk.Threads.threadsAddIdle(&pluginUninstall_idleFetch, null);
		spawn(&pluginUninstall, inputPath);
		pluginUninstalling = true;
	}

	void onCompletedPage(Widget) {

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

		string logoPath = buildPath(inputPath, "assets", "icon.png");
		pihIcon.setFromFile(logoPath);
		pihTitle.setLabel(info.name);
		pihDescription.setLabel(info.description);

		piiID.setLabel(info.id);
		piiVersion.setLabel(info.strVersion);
		piiAuthors.setLabel(arrayToString(info.authors));
		piiURL.setLabel(url(info.url));
		piiType.setLabel("Official");
	}

	void appendPluginUninstallTextBuffer(string line) {
		TextIter end_iter;
		pluginUninstallTextBuffer.getEndIter(end_iter);
		pluginUninstallTextBuffer.insert(end_iter, line ~ "\n");
	}

	void completedPluginUninstallation() {
		pPluginLabel.setMarkup(italic("Completed"));
		pPluginSpinner.stop();
		wizard.setPageComplete(wizard.getNthPage(Pages.PLUGIN_UNINSTALL), true);
	}
}

void pluginUninstall(string pluginPath) {
	writeln("Uninstalling plugin...");
	rmdirRecurse(pluginPath);

	ownerTid.send("Completed");
	writeln("Finished plugin installation");
}

shared bool pluginUninstalling = false;
extern(C) nothrow int pluginUninstall_idleFetch(void* data) {
	try {
		receive((string output) {
			app.appendPluginUninstallTextBuffer(output);
			if(output == "Completed") {
				app.completedPluginUninstallation();
				pluginUninstalling = false;
			}
		});
		if(!pluginUninstalling) {
			return 0;
		}
	} catch(Exception) return 0;

	return 1;
}