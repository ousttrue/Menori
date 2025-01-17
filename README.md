# Menori

LÖVE library for 3D rendering based on scene graph. Support glTF 2.0 (implemented: meshes, materials, textures, skins, skeletons, animations). Assets may be provided either in JSON (.gltf) or binary (.glb) format.

Works on LÖVE 11.4 and higher.

[Web version](https://rozenmad.github.io/menori_demo1201/)
Built using [love-web-builder](https://github.com/rozenmad/love-web-builder)

[Documentation](https://rozenmad.github.io)

You can generate documentation using `ldoc -c menori/docs/config.ld -o index .`

![preview_example](preview.png)

## mod

- type annotation: https://luals.github.io/wiki/annotations/

### luarock development

```
Menori
  + luarocks
    + bin
      + activate.ps1
      + lua.exe
```

```sh
> hererocks -j 2.1 --luarocks latest luarocks
> rm -rf $env:APPDATA\luarocks
> .\luarocks\bin\activate.ps1
> lua -v
LuaJIT 2.1.0-beta3 -- Copyright (C) 2005-2017 Mike Pall. http://luajit.org/
```

```lua
-- luarocks\luarocks\config-5.1.lua
rocks_trees = {
    -- remove user
    { name = [[system]],
         root    = [[PATH_TO_MENORI\luarocks\]],
    },
}
variables = {
    MSVCRT = 'VCRUNTIME140',
    LUALIB = 'lua51.lib',
}
verbose = false   -- set to 'true' to enable verbose output
-- vs version
cmake_generator = "Visual Studio 17 2022"
```

#### setup local love2d

```sh
> git clone https://github.com/love2d/megasource megasource
> git clone https://github.com/love2d/love megasource/libs/love
> cd megasource
megasource> luarocks write_rockspec
```

```lua
-- megasource\megasource-dev-1.rockspec
package = "megasource"
version = "dev-1"
source = {
  url = "...",
}
description = {
  summary = "It is currently only officially supported on Windows, but may also work on macOS.",
  detailed =
  "It is currently only officially supported on Windows, but may also work on macOS. It could certainly also work on Linux, but good package managers makes megasource less relevant there.",
  homepage = "https://github.com/love2d/megasource",
  license = "*** please specify a license ***",
}
build = {
  type = "cmake",
  variables = {
    -- find_package (LuaJIT)
    LUA_LIBDIR = "$(LUA_LIBDIR)",
    LUA_INCDIR = "$(LUA_INCDIR)",
    LUA_LIBFILE = "$(LUALIB)",
    LUAJIT_DIR = "$(LUA_DIR)",
    LUA = "$(LUA)",
    -- install destination
    CMAKE_INSTALL_PREFIX = "prefix",
    -- CMAKE_INSTALL_PREFIX = "$(LIBDIR)",
  },
  install = {
    lib = {
      "prefix/love.dll",
      "prefix/OpenAL32.dll",
      "prefix/SDL3.dll",
    },
    bin = {
      "prefix/love.exe",
    },
  },
}
```

```sh
megasource> luarocks make
Error: failed deploying files. The following files were not installed:
luarocks\/bin/OpenAL32.dll.bat
luarocks\/bin/SDL3.dll.bat
megasource> cd ..
> fd -I dll .\luarocks\
.\luarocks\lib\lua\5.1\OpenAL32.dll
.\luarocks\lib\lua\5.1\SDL3.dll
.\luarocks\lib\lua\5.1\love.dll
```

### cimgui

https://codeberg.org/apicici/cimgui-love

- cimgui/init.lua
- dll => luarocks/bin/cimgui.dll (any of PATH enviroment)

## License

MIT
