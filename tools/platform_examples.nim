import std/[os, osproc, strformat, strutils]

const
  allExamples = [
    "window_smoke",
    "shapes",
    "scene_stack",
    "imgui_overlay",
    "diagnostics_overlay",
    "particles_basic",
    "light2d_basic",
    "audio_basic",
    "physics_basic",
    "prefab_basic",
    "atlas_basic",
    "text_test",
    "ui_layout",
    "breakout",
    "blink",
    "hex",
    "hotreload",
    "imgui_showcase",
    "imgui_cjk"
  ]

  webExamples = [
    "window_smoke",
    "shapes",
    "scene_stack",
    "imgui_overlay",
    "diagnostics_overlay",
    "particles_basic",
    "light2d_basic",
    "audio_basic",
    "physics_basic",
    "prefab_basic",
    "atlas_basic",
    "text_test",
    "ui_layout",
    "breakout",
    "blink",
    "hex",
    "imgui_showcase",
    "imgui_cjk"
  ]

type Target = enum
  tHeadless = "headless"
  tSdl = "sdl"
  tSdlGpu = "sdlgpu"
  tWeb = "web"
  tWindows = "windows"
  tLinux = "linux"

proc die(message: string) =
  stderr.writeLine(message)
  quit 1

proc requireCommand(name: string) =
  if findExe(name).len == 0:
    die "Required command not found: " & name

proc shell(command: string) =
  echo command
  let code = execCmd(command)
  if code != 0:
    quit code

proc envAssign(name, value: string): string =
  name & "=" & quoteShell(value)

proc binaryenPath(): string =
  var entries: seq[string]
  for path in [
    "/opt/homebrew/opt/python@3.14/bin",
    "/usr/local/opt/python@3.14/bin",
    "/opt/homebrew/opt/binaryen/bin",
    "/usr/local/opt/binaryen/bin",
    "/opt/homebrew/opt/lld/bin",
    "/usr/local/opt/lld/bin",
    "/opt/homebrew/bin",
    "/usr/local/bin"
  ]:
    if dirExists(path):
      entries.add path
  if entries.len == 0:
    getEnv("PATH")
  else:
    entries.join(":") & ":" & getEnv("PATH")

proc emConfigPath(): string =
  getEnv("EM_CONFIG", getCurrentDir() / "build" / "emscripten" / ".emscripten")

proc emCachePath(): string =
  getEnv("EM_CACHE", getCurrentDir() / "build" / "emscripten" / "cache-nothreads")

proc firstToolDir(tool: string, dirs: openArray[string]): string =
  for dir in dirs:
    if fileExists(dir / tool):
      return dir

proc linkToolDir(srcDir, dstDir: string) =
  for kind, path in walkDir(srcDir):
    if kind in {pcFile, pcLinkToFile}:
      let dst = dstDir / extractFilename(path)
      if not fileExists(dst) and not symlinkExists(dst):
        createSymlink(path, dst)

proc emLlvmRootPath(): string =
  let configured = getEnv("EM_LLVM_ROOT")
  if configured.len > 0 and fileExists(configured / "wasm-ld"):
    return configured

  let llvmDir = firstToolDir("clang", [
    "/opt/homebrew/opt/llvm/bin",
    "/usr/local/opt/llvm/bin",
    "/opt/homebrew/bin",
    "/usr/local/bin"
  ])
  let lldDir = firstToolDir("wasm-ld", [
    "/opt/homebrew/opt/lld/bin",
    "/usr/local/opt/lld/bin",
    "/opt/homebrew/bin",
    "/usr/local/bin"
  ])

  if llvmDir.len == 0:
    return ""
  if fileExists(llvmDir / "wasm-ld"):
    return llvmDir
  if lldDir.len == 0:
    return llvmDir

  let shim = getCurrentDir() / "build" / "emscripten" / "llvm-root"
  createDir(shim)
  linkToolDir(llvmDir, shim)
  linkToolDir(lldDir, shim)
  shim

proc emEnvPrefix(): string =
  var prefix = envAssign("EM_CONFIG", emConfigPath())
  prefix.add " " & envAssign("EM_CACHE", emCachePath())
  let llvmRoot = emLlvmRootPath()
  if llvmRoot.len > 0:
    prefix.add " " & envAssign("EM_LLVM_ROOT", llvmRoot)
  for path in ["/opt/homebrew/opt/binaryen", "/usr/local/opt/binaryen"]:
    if dirExists(path):
      prefix.add " " & envAssign("EM_BINARYEN_ROOT", path)
      break
  prefix & " " & envAssign("PATH", binaryenPath())

proc ensureEmscriptenConfig() =
  let config = emConfigPath()
  createDir(emCachePath())
  if fileExists(config):
    return
  createDir(config.parentDir)
  shell emEnvPrefix() & " emcc --generate-config"

proc sdl3EmscriptenPrefix(): string =
  let configured = getEnv("SDL3_EMSCRIPTEN_PREFIX")
  if configured.len > 0:
    return configured
  getCurrentDir() / "build" / "sdl3-emscripten-prefix"

proc parseTarget(value: string): Target =
  for target in Target:
    if $target == value:
      return target
  die "Unsupported target: " & value

proc parseExamples(value: string, target: Target): seq[string] =
  let supported = if target == tWeb: @webExamples else: @allExamples
  if value.len == 0 or value == "all":
    return supported
  for item in value.split(','):
    let name = item.strip()
    if name.len == 0:
      continue
    if name notin supported:
      die &"Unsupported example for {$target}: {name}"
    result.add name

proc copyAssets(outDir: string) =
  if dirExists("assets"):
    let dst = outDir / "assets"
    if dirExists(dst):
      removeDir(dst)
    copyDir("assets", dst)

proc resetDir(path: string) =
  if dirExists(path):
    removeDir(path)
  createDir(path)

proc copyLinuxDockerOutput(hostOut, outRoot, examplesArg: string) =
  for name in parseExamples(examplesArg, tLinux):
    let src = hostOut / "linux" / name
    if not dirExists(src):
      die "Linux Docker output not found: " & src
    let dst = outRoot / "linux" / name
    if dirExists(dst):
      removeDir(dst)
    createDir(dst.parentDir)
    copyDir(src, dst)

proc checkTarget(target: Target) =
  requireCommand("nim")
  case target
  of tWeb:
    requireCommand("emcc")
    ensureEmscriptenConfig()
    let lib = sdl3EmscriptenPrefix() / "lib" / "libSDL3.a"
    if not fileExists(lib):
      die "SDL3 Emscripten library not found: " & lib &
        "\nRun `nimble sdl3Emscripten` or set SDL3_EMSCRIPTEN_PREFIX."
  of tWindows:
    requireCommand("x86_64-w64-mingw32-gcc")
    requireCommand("x86_64-w64-mingw32-g++")
  of tLinux:
    when not defined(linux):
      die "Linux examples must be built on Linux or inside a Linux builder."
  else:
    discard

proc runLinuxDocker(examplesArg, outRoot: string, run, package, checkOnly: bool) =
  when defined(linux):
    discard
  else:
    if run:
      die "Linux Docker builder only supports build/package. Run examples on a Linux desktop."
    requireCommand("docker")
    if checkOnly:
      shell "docker info"
      echo "Tools OK for target: linux"
      quit 0

    let image = getEnv("NIMA_LINUX_DOCKER_IMAGE", "nima-linux-builder")
    shell "docker build -f " & quoteShell("tools/linux.Dockerfile") &
      " -t " & quoteShell(image) & " ."

    let hostOut = getTempDir() / "nima-linux-output-" & $getCurrentProcessId()
    resetDir(hostOut)

    var inner = "nim r --nimcache:nimcache/platform_examples_tool_linux " &
      "tools/platform_examples.nim -- --target:linux --example:" & examplesArg
    if package:
      inner.add " --package"
    inner.add " --out:/out"

    shell "docker run --rm -v " & quoteShell(hostOut & ":/out") &
      " -w /workspace " & quoteShell(image) &
      " sh -c " & quoteShell(inner)
    copyLinuxDockerOutput(hostOut, outRoot, examplesArg)
    removeDir(hostOut)
    quit 0

proc buildCommand(target: Target, name, outRoot: string, run: bool): string =
  case target
  of tHeadless:
    let runFlag = if run: " -r" else: ""
    &"nim c{runFlag} --nimcache:nimcache/platform_headless_{name} examples/{name}.nim"
  of tSdl:
    let runFlag = if run: " -r" else: ""
    &"nim c{runFlag} --nimcache:nimcache/platform_sdl_{name} -d:nimaUseSdl examples/{name}.nim"
  of tSdlGpu:
    let runFlag = if run: " -r" else: ""
    &"nim c{runFlag} --nimcache:nimcache/platform_sdlgpu_{name} -d:nimaUseSdlGpu examples/{name}.nim"
  of tWeb:
    let outDir = outRoot / "web" / name
    resetDir(outDir)
    let prefix = sdl3EmscriptenPrefix()
    emEnvPrefix() & " " & envAssign("SDL3_EMSCRIPTEN_PREFIX", prefix) &
      &" nim c -f -d:emscripten --nimcache:nimcache/platform_web_{name} -o:{outDir / \"index.html\"} examples/{name}.nim"
  of tWindows:
    let outDir = outRoot / "windows" / name
    resetDir(outDir)
    &"nim --cpu:amd64 --os:windows --app:console -f --gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-g++ -d:nimaUseSdl --nimcache:nimcache/platform_windows_{name} -o:{outDir / (name & \".exe\")} c examples/{name}.nim"
  of tLinux:
    let outDir = outRoot / "linux" / name
    resetDir(outDir)
    let runFlag = if run: " -r" else: ""
    &"nim c{runFlag} -f -d:nimaUseSdl --nimcache:nimcache/platform_linux_{name} -o:{outDir / name} examples/{name}.nim"

proc packageExample(target: Target, name, outRoot: string) =
  case target
  of tWindows:
    let outDir = outRoot / "windows" / name
    copyAssets(outDir)
    if getEnv("SDL3_WINDOWS_DLL_DIR").len > 0:
      for dll in ["SDL3.dll", "SDL3_ttf.dll", "SDL3_image.dll", "SDL3_mixer.dll"]:
        let src = getEnv("SDL3_WINDOWS_DLL_DIR") / dll
        if fileExists(src):
          copyFile(src, outDir / dll)
  of tLinux:
    copyAssets(outRoot / "linux" / name)
    if getEnv("SDL3_LINUX_LIB_DIR").len > 0:
      for lib in ["libSDL3.so", "libSDL3.so.0"]:
        let src = getEnv("SDL3_LINUX_LIB_DIR") / lib
        if fileExists(src):
          copyFile(src, outRoot / "linux" / name / lib)
  else:
    discard

proc usage() =
  echo """
Usage:
  nim r tools/platform_examples.nim -- --target:<target> [--example:<name|a,b|all>] [--run] [--package] [--out:<dir>] [--check-tools]

Targets:
  headless, sdl, sdlgpu, web, windows, linux
"""

when isMainModule:
  var
    target = tHeadless
    examplesArg = "all"
    outRoot = "build"
    run = false
    package = false
    checkOnly = false

  for arg in commandLineParams():
    if arg == "--":
      discard
    elif arg == "--help" or arg == "-h":
      usage()
      quit 0
    elif arg.startsWith("--target:"):
      target = parseTarget(arg.split(":", maxsplit = 1)[1])
    elif arg.startsWith("--example:"):
      examplesArg = arg.split(":", maxsplit = 1)[1]
    elif arg.startsWith("--out:"):
      outRoot = arg.split(":", maxsplit = 1)[1]
    elif arg == "--run":
      run = true
    elif arg == "--package":
      package = true
    elif arg == "--check-tools":
      checkOnly = true
    else:
      die "Unknown argument: " & arg

  if target == tLinux:
    runLinuxDocker(examplesArg, outRoot, run, package, checkOnly)

  checkTarget(target)
  if checkOnly:
    echo "Tools OK for target: ", $target
    quit 0

  for name in parseExamples(examplesArg, target):
    shell buildCommand(target, name, outRoot, run)
    if package:
      packageExample(target, name, outRoot)
