import std/[os, osproc, strformat, strutils]

type
  Shader = object
    stem: string
    filename: string
    stage: string

  Target = object
    name: string
    dest: string
    ext: string

const
  shaders = [
    Shader(stem: "quad.vert", filename: "quad.vert.hlsl", stage: "vertex"),
    Shader(stem: "quad.frag", filename: "quad.frag.hlsl", stage: "fragment"),
    Shader(stem: "sprite.vert", filename: "sprite.vert.hlsl", stage: "vertex"),
    Shader(stem: "sprite.frag", filename: "sprite.frag.hlsl", stage: "fragment")
  ]

  targets = [
    Target(name: "msl", dest: "MSL", ext: "msl"),
    Target(name: "spirv", dest: "SPIRV", ext: "spv"),
    Target(name: "dxil", dest: "DXIL", ext: "dxil")
  ]

proc projectRoot(): string =
  let cwd = getCurrentDir()
  if dirExists(cwd / "assets" / "shaders" / "source"):
    cwd
  elif dirExists(cwd.parentDir / "assets" / "shaders" / "source"):
    cwd.parentDir
  else:
    cwd

proc findShadercross(): string =
  for candidate in ["shadercross", "SDL_shadercross", "sdl-shadercross",
                    "sdl3-shadercross"]:
    let path = findExe(candidate)
    if path.len > 0:
      return path

proc selectedTargets(): seq[Target] =
  let args = commandLineParams()
  if args.len == 0:
    return @targets

  for name in args:
    let normalized = name.toLowerAscii()
    var found = false
    for target in targets:
      if normalized == target.name:
        result.add target
        found = true
        break
    if not found:
      raise newException(ValueError,
        "unknown shader target '" & name & "'; expected msl, spirv, or dxil")

proc compileShader(shadercross, sourceDir, outputRoot: string;
                   shader: Shader; target: Target) =
  let source = sourceDir / shader.filename
  let outDir = outputRoot / target.name
  let output = outDir / (shader.stem & "." & target.ext)
  createDir(outDir)

  let command = quoteShellCommand([
    shadercross,
    source,
    "-s", "HLSL",
    "-d", target.dest,
    "-t", shader.stage,
    "-e", "main",
    "-o", output
  ])
  let (log, code) = execCmdEx(command)
  if code != 0:
    if log.strip.len > 0:
      stderr.write(log)
    raise newException(OSError,
      &"shadercross failed for {shader.filename} -> {target.name}")
  echo "[Nima] shader ", shader.filename, " -> ", target.name

when isMainModule:
  let shadercross = findShadercross()
  if shadercross.len == 0:
    echo "[Nima] shadercross not found; skipping shader rebuild"
    echo "[Nima] install SDL_shadercross to generate assets/shaders/compiled blobs"
    quit 0

  let root = projectRoot()
  let sourceDir = root / "assets" / "shaders" / "source"
  let outputRoot = root / "assets" / "shaders" / "compiled"
  for shader in shaders:
    let source = sourceDir / shader.filename
    if not fileExists(source):
      raise newException(IOError, "missing shader source " & source)

  for target in selectedTargets():
    for shader in shaders:
      compileShader(shadercross, sourceDir, outputRoot, shader, target)
