module src.connection._debug;

import connection.boilerplate;
import plugin.plugin;

import std.file : remove;
import std.stdio;

/*
 * DebugBackend - Debug communication backend
 * Uses a local file to perform communication
 **/
class DebugBackend : ConnectionBackend {
	override {
		void startup() {

		}

		void cleanup() {
			remove("commFile");
		}

		void queue(PluginInfo pInfo) {

		}

		void send() {
			return;
		}

		void receive() {
			// Makes a file on current executable path
			commFile = File("commFile");

			while(!commFile.eof) {
				
			}
		}

		void onEvent(PluginInfo pInfo) {
			
		}
	}

private:
	File commFile;
}