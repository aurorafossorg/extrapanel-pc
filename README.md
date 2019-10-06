# PC App

PC version of Extra Panel

![Pre-Alpha Screenshot 1](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-1.png)
![Pre-Alpha Screenshot 2](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-2.png)
![Pre-Alpha Screenshot 3](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-3.png)
![Pre-Alpha Screenshot 4](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-4.png)

## Dependencies

- [**dmd**](https://dlang.org/download.html) or [**ldc**](https://dlang.org/download.html)
- [**dub**](https://code.dlang.org/download)
- [**gtk3**](https://www.gtk.org/download/index.php)
- [**lua**](https://www.lua.org/download.html) *>= 5.3*
- [**luarocks**](https://github.com/luarocks/luarocks/wiki/Download)
- [**lua-lgi**](https://github.com/pavouk/lgi)

### Arch Linux

You can either use `dmd` or `ldc`:

```bash
pacman -S dub dmd gtk3 lua luarocks lua-lgi
```

### Ubuntu

For Ubuntu, only `ldc` has been reported to work:

```bash
apt install libgtkd-3-dev glib2.0 lua5.3-dev lua-lgi gobject-introspection libgirepository1.0-dev
snap install dub --classic
snap install ldc2 --classic
```

You will have to manually compile `luarocks` yourself, because the Ubuntu package is for Lua 5.1. You can find instructions to compile it [here](https://github.com/luarocks/luarocks/wiki/installation-instructions-for-unix).

## Compiling

You can use the tool to compile every module:

```bash
./tools/dub.sh build
```

Or run every command in separate:

```bash
dub build :app 		# Compiles the UI app
dub build :manager	# Compiles the plugin manager
dub build :daemon 	# Compiles the daemon
dub build :tray		# Compiles the tray icon
```

Installing is **not recommended.** The install script is very barebones and can make permanent unwanted changes to your system. To install it anyways, run:

```bash
sudo ./install.py
```

After install, you will now have 3 main executables:

 - `extrapanel` - **configuration UI** *(alternatively under the Utility/Accessories section of your menu bar)*
 - `extrapanel-daemon` - **daemon**
 - `extrapanel-tray` - **tray icon**

There is another executable meant for internal usage but that can be use standalone, nevertheless:

 - `extrapanel-manager` - **plugin manager for install/uninstall**