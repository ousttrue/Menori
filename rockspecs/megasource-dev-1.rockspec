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
