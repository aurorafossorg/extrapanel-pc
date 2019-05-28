module util.exception;

public class FileNotFoundException : Exception {
	this(string msg) {
		super("File \"" ~ msg ~ "\" doesn't exist.", file, line);
	}
}

public class ScriptExecutionException : Exception {
	this(string script, string method) {
		super("Script \"" ~ script ~ "\" failed on executing " ~ method ~ "().", file, line);
	}
}