# PC App

PC version of Extra Panel

![Pre-Alpha Screenshot](https://gitlab.com/aurorafossorg/p/extra-panel/assets/raw/master/screenshots/pre-alpha1.png)

## Compiling

### Dependencies

- [**gtkd**](https://gtkd.org/) *(=>3.6)*
- [**meson**](https://mesonbuild.com/) *(<=0.47.2-1)*
- [**ninja**](https://ninja-build.org/)
- [**dmd**](https://dlang.org/)

*(assuming building directory as `build`)*
```bash
meson build
ninja -C build
ninja -C build install
```

You can now run the app with `extrapanel` command. *(alternatively under the Utility/Accessories section of your menu bar)*

## Credits

[**UUIDGenerator**](https://www.uuidgenerator.net/) - UUID Generator