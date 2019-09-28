module extrapanel.core.util.exception;

public class FileNotFoundException : Exception {
	this(string msg) {
		super("File \"" ~ msg ~ "\" doesn't exist.", file, line);
	}
}

public class ScriptMethodExecutionException : Exception {
	this(string script, string method) {
		super("Script \"" ~ script ~ "\" failed on executing " ~ method ~ "().", file, line);
	}
}

public class ScriptLoadingException : Exception {
	this(string script) {
		super("Script\"" ~ script ~ "\" failed on loading.", file, line);
	}
}