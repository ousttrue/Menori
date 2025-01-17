#
# init luarocks
#
if(-not (Test-Path luarocks))
{
  hererocks -j 2.1 --luarocks latest luarocks
  Set-Content -Path "luarocks/luarocks/config-5.1.lua" -Force -Value @"
rocks_trees = {
    { name = [[system]],
         root    = [[$(Get-Location)\luarocks\]],
    },
}
variables = {
    MSVCRT = 'VCRUNTIME140',
    LUALIB = 'lua51.lib',
}
verbose = false   -- set to 'true' to enable verbose output
cmake_generator = "Visual Studio 17 2022"
"@
  luarocks-admin --global
}
.\luarocks\bin\activate.ps1
lua.exe -v

#
# build love2d
#
if(-not (Test-Path megasource))
{
  if(-not (Test-Path megasource))
  {
    git clone https://github.com/love2d/megasource megasource
  }
  if(-not (Test-Path megasource/libs/love))
  {
    git clone https://github.com/love2d/love megasource/libs/love
  }
  Copy-Item rockspecs/megasource-dev-1.rockspec megasource
  Push-Location megasource
  luarocks make
  Pop-Location
}

#
# build cimgui
#
# https://codeberg.org/apicici/cimgui-love
if(-not (Test-Path cimgui-love))
{
  git clone --recursive https://codeberg.org/apicici/cimgui-love.git cimgui-love
  # patch
}
Push-Location cimgui-love/cimgui/generator
$env:LUA_PATH="$(Get-Location)\\?.lua"
lua generator.lua cl "internal"
Pop-Location

Push-Location cimgui-love/cimgui
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
Pop-Location
Copy-Item cimgui-love/cimgui/build/Release/cimgui.dll luarocks/bin/cimgui.dll

if(Test-Path cimgui){
  Remove-Item -Recurse cimgui -Force
}
Copy-Item -Recurse cimgui-love/src ./cimgui