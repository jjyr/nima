--gc:arc
--hints:off
--path:"src"
--nimcache:"nimcache"

when defined(Windows):
  switch("passL", "-static-libstdc++ -static-libgcc")

when defined(MacOSX):
  switch("clang.linkerexe", "g++")
  switch("passL", "-L/opt/homebrew/lib -Wl,-rpath,/opt/homebrew/lib")
  switch("passL", "-L/usr/local/lib -Wl,-rpath,/usr/local/lib")
else:
  switch("gcc.linkerexe", "g++")
