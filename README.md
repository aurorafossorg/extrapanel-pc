# PC App

PC version of Extra Panel

![Pre-Alpha Screenshot 1](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-1.png)
![Pre-Alpha Screenshot 2](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-2.png)
![Pre-Alpha Screenshot 3](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-3.png)
![Pre-Alpha Screenshot 4](https://dl.aurorafoss.org/aurorafoss/pub/assets/xpanel/pre-alpha3-4.png)


## Compiling

### Dependencies

- [**gtkd**](https://gtkd.org/) *(=>3.6)*
- [**meson**](https://mesonbuild.com/) *(you need to build from [source](https://github.com/mesonbuild/meson) since the latest release doesn't work yet)*
- [**ninja**](https://ninja-build.org/)
- [**dmd**](https://dlang.org/)

*(assuming building directory as `build`)*
```bash
meson build
ninja -C build
ninja -C build install
```

You have now 3 executables installed:

 - `extrapanel` - **configuration UI** *(alternatively under the Utility/Accessories section of your menu bar)*
 - `extrapanel-daemon` - **daemon**
 - `extrapanel-tray` - **tray icon**

## Credits

[**UUIDGenerator**](https://www.uuidgenerator.net/) - UUID Generator