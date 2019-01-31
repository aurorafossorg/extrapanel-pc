module extrapanel.app;

// STD
import std.stdio;
import std.file;
import std.experimental.logger;

// GTK
// Types
import gtk.c.types;

// Top level
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Widget;
import gtk.Window;

// Contruct
import gtk.Builder;

// Elements
import gtk.Box;
import gtk.Button;
import gtk.ButtonBox;
import gtk.DrawingArea;
import gtk.Fixed;
import gtk.HeaderBar;
import gtk.Image;
import gtk.Label;
import gtk.MenuButton;
import gtk.Overlay;
import gtk.Popover;
import gtk.ProgressBar;
import gtk.Scale;
import gtk.SpinButton;
import gtk.Spinner;
import gtk.Switch;

// 
// Gio
// 

// Top level
import gio.Application : GApplication = Application;

// Elements
import gio.Menu : GMenu = Menu;
import gio.MenuItem : GMenuItem = MenuItem;

// GDK
import gdkpixbuf.Pixbuf;
import gdkpixbuf.PixbufLoader;

/// Main application
class ExtraPanelGUI : Application
{

public:

	/// Constructor
	this()
	{
		ApplicationFlags flags = ApplicationFlags.FLAGS_NONE;
		super("org.aurorafoss.extrapanel", flags);
		this.window = null;
		this.addOnActivate(&onAppActivate);
	}

private:
	void onAppActivate(GApplication app)
	{
		trace("Activate App Signal");
		if (!app.getIsRemote())
		{
			// Loads the UI files
			builder = new Builder();
			if(!builder.addFromResource("/org/aurorafoss/extrapanel/ui/window.ui"))
			{
				critical("Window resource cannot be found");
				return;
			}

			// Setup the app
			initElements();
		}

		// Show
		this.window.present();
	}

	// Contruct
	Builder builder;

	// Window
	ApplicationWindow window;

	// Inits the builder defined elements
	void initElements()
	{
		// Top level
		window = cast(ApplicationWindow) builder.getObject("window");
		window.setApplication(this);
	}
}