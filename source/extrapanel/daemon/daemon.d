module extrapanel.daemon.daemon;

import extrapanel.core.util.config;
import extrapanel.core.util.paths;
import extrapanel.core.plugin.info;
import extrapanel.daemon.plugin.runner;
import extrapanel.core.util.logger;

import core.stdc.stdlib;
import core.sys.posix.unistd;
import core.sys.posix.signal;
import core.sys.linux.errno;
import core.thread;
import core.time;

import std.file;
import std.stdio;
import std.math;
import std.process;
import std.conv;

extern (C)
{
	// These are for control of termination
	// druntime rt.critical_
	// TODO: Investigate what these do and if they're needed
	//void _d_critical_term();
	// druntime rt.monitor_
	//void _d_monitor_staticdtor();

	//void gc_term();

	alias int pid_t;

	// daemon functions
	pid_t fork();
	int umask(int);
	int setsid();
	int close(int fd);

	// Signal trapping in Linux
	alias void function(int) sighandler_t;
	sighandler_t signal(int signum, sighandler_t handler);
	char* strerror(int errnum) pure;
}

// Signal handler for the daemon
extern (C) void signalHandler(int signal) {
	logger.info("Signal: ", signal);
	shouldExit = true;
}

bool shouldExit = false;

// Checks for existance of the lock file
bool lockFileExists() {
	return exists(appConfigPath() ~ LOCK_PATH);
}

// Generates lock file
void makeLockFile(pid_t pid) {
	File lockF = File(appConfigPath() ~ LOCK_PATH, "w");
	lockF.write(to!string(pid));
	lockF.close();
}

// Deletes lock file
void deleteLockFile() {
	remove(appConfigPath() ~ LOCK_PATH);
}

// Gets the delay in miliseconds from the config file
int getMsecsDelay() {
	return cast(int) round(Configuration.getOption!(float)(Options.CommDelay) * 1000);
}

pid_t daemonize() {
	// Process and Session ID's
	pid_t pid, sid;

	// Fork of of parent
	pid = fork();

	if(pid < 0) {
		logger.critical("Daemon process failed: fork failed");
		deleteLockFile();
		logger.file.close();

		exit(EXIT_FAILURE);
	}

	// Forking successfull, leaving parent
	if(pid > 0) {
		exit(EXIT_SUCCESS);
	}

	// Change umask mode
	umask(0);

	// Creates a new SID for the child process
	sid = setsid();
	if(sid < 0) {
		deleteLockFile();
		logger.file.close();

		exit(EXIT_FAILURE);
	}

	makeLockFile(sid);

	// Closes file descriptors
	close(STDIN_FILENO);
	close(STDOUT_FILENO);
	close(STDERR_FILENO);

	// Daemon process finished; we return it's pid now
	return pid;
}

PluginRunner pluginRunner;

int main(string[] args) {
	// Init logger
	initLogger();

	// Appends args to global args
	Configuration.appArgs ~= args;
	
	// Check for existence of lock file
	if(lockFileExists && !Configuration.hasArg("--overwrite")) {
		writeln("Lock file already exists! If you're sure no daemon is running, delete " ~ appConfigPath() ~ LOCK_PATH ~ " manually");
		return -1;
	}

	// Daemonize
	int pid = daemonize();

	// Makes lock file and loads general config
	Configuration.load();

	// Connect signals to signalHandler
	signal(SIGINT, &signalHandler);
	signal(SIGABRT, &signalHandler);
	signal(SIGQUIT, &signalHandler);
	signal(SIGTERM, &signalHandler);

	// Setup our plugin runner
	pluginRunner = new PluginRunner();

	// Main loop
	while(!shouldExit) {
		string[] query = pluginRunner.query();
		logger.trace(query);

		Thread.sleep(getMsecsDelay.dur!"msecs");
	}

	// Daemon is quitting
	destroy(pluginRunner);
	logger.info("Daemon is quitting...");
	logger.file.close();
	deleteLockFile();

	return 0;
}