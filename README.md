# PC App

PC version of Extra Panel

![Pre-Alpha Screenshot 1](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-1.png)
![Pre-Alpha Screenshot 2](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-2.png)
![Pre-Alpha Screenshot 3](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-3.png)
![Pre-Alpha Screenshot 4](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-4.png)


## Compiling

### Dependencies

- [**dmd**](https://dlang.org/)
- [**dub**](https://code.dlang.org/)

```bash
dub build extrapanel:ui 		# Compiles the UI app
dub build extrapanel:manager	# Compiles the plugin manager
dub build extrapanel:daemon 	# Compiles the daemon
dub build extrapanel:tray		# Compiles the tray icon
```

To install them, run:

```bash
sudo ./install.py
```

You have now 3 executables:

 - `extrapanel` - **configuration UI** *(alternatively under the Utility/Accessories section of your menu bar)*
 - `extrapanel-daemon` - **daemon**
 - `extrapanel-tray` - **tray icon**
 - `extrapanel-manager` - **plugin manager for install/uninstall** *(this is meant for internal usage, you shouldn't need to use it directly)*

## Credits