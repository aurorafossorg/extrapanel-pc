module extrapanel.core.util.formatter;

// Extra Panel
version (unittest) import extrapanel.core.util.logger;

// Pango
import pango.PgAttribute;


/**
 * Formats a text to become bold.
 *
 * Params:
 *		text = raw string to format.
 *
 * Returns: string with formatting added.
 */
public static string bold(string text) {
	return "<b>" ~ text ~ "</b>";
}

/**
 * Formats a text to become italic.
 *
 * Params:
 *		text = raw string to format.
 *
 * Returns: string with formatting added.
 */
public static string italic(string text) {
	return "<i>" ~ text ~ "</i>";
}

/**
 * Formats a text to become monospaced.
 *
 * Params:
 *		text = raw string to format.
 *
 * Returns: string with formatting added.
 */
public static string monospaced(string text) {
	return "<tt>" ~ text ~ "</tt>";
}

/**
 * Formats a text to become an URL.
 *
 * Params:
 *		text = raw string to format.
 *
 * Returns: string with formatting added.
 */
public static string url(string text) {
	return "<a href=\"" ~ text ~ "\">" ~ text ~ "</a>";
}

/**
 * Formats a text to appear green on the console.
 *
 * Params:
 *		text = raw string to format.
 *
 * Returns: string with formatting added.
 */
public static string consoleGreen(string text) {
	return "\033[0;32m" ~ text ~ "\033[0m";
}

/**
 * Formats a text to appear yellow on the console.
 *
 * Params:
 *		text = raw string to format.
 *
 * Returns: string with formatting added.
 */
public static string consoleYellow(string text) {
	return "\033[1;33m" ~ text ~ "\033[0m";
}

/**
 * Formats a text to appear red on the console.
 *
 * Params:
 *		text = raw string to format.
 *
 * Returns: string with formatting added.
 */
public static string consoleRed(string text) {
	return "\033[0;31m" ~ text ~ "\033[0m";
}

/**
 * Creates an UI attribute to represent bold text.
 *
 * Returns: The PgAttribute to use in the UI.
 */
public static PgAttribute uiBold() {
	return PgAttribute.weightNew(PangoWeight.BOLD);
}

/**
 * Creates an UI attribute to represent italic text.
 *
 * Returns: The PgAttribute to use in the UI.
 */
public static PgAttribute uiItalic() {
	return PgAttribute.styleNew(PangoStyle.ITALIC);
}

/**
 * Creates an UI attribute to represent red text.
 *
 * Returns: The PgAttribute to use in the UI.
 */
public static PgAttribute uiRed() {
	return PgAttribute.foregroundNew(0xcccc, 0x0000, 0x0000);
}

/**
 * Creates an UI attribute to represent green text.
 *
 * Returns: The PgAttribute to use in the UI.
 */
public static PgAttribute uiGreen() {
	return PgAttribute.foregroundNew(0x4e4e, 0x9a9a, 0x0606);
}

/**
 * Creates an UI attribute to represent grey text.
 *
 * Returns: The PgAttribute to use in the UI.
 */
public static PgAttribute uiGrey() {
	return PgAttribute.foregroundNew(0xaaaa, 0xaaaa, 0xaaaa);
}

@("Formatter: bold text")
unittest {
	string text = "example-text";

	assert(bold(text) == "<b>example-text</b>");
}

@("Formatter: italic text")
unittest {
	string text = "example-text";

	assert(italic(text) == "<i>example-text</i>");
}

@("Formatter: monospaced text")
unittest {
	string text = "example-text";

	assert(monospaced(text) == "<tt>example-text</tt>");
}

@("Formatter: url text")
unittest {
	string text = "http://example-url.com";

	assert(url(text) == "<a href=\"http://example-url.com\">http://example-url.com</a>");
}

@("Formatter: console red text")
unittest {
	string text = "This should appear red on console";

	info(consoleRed(text));
	assert(consoleRed(text) == "\033[0;31mThis should appear red on console\033[0m");
}

@("Formatter: console yellow text")
unittest {
	string text = "This should appear yellow on console";

	info(consoleYellow(text));
	assert(consoleYellow(text) == "\033[1;33mThis should appear yellow on console\033[0m");
}

@("Formatter: console green text")
unittest {
	string text = "This should appear green on console";

	info(consoleGreen(text));
	assert(consoleGreen(text) == "\033[0;32mThis should appear green on console\033[0m");
}

@("Formatter: UI formatting objects")
unittest {
	// Assert every UI formatting method returns a valid object
	assert(uiBold());
	assert(uiItalic());

	assert(uiGreen());
	assert(uiRed());
	assert(uiGrey());
}