import pkg/stb_image/read as stbi

type
  ImageLoadError* = object of CatchableError

  ImagePixels* = object
    width*, height*: int32
    pixels*: seq[uint8]

proc loadImageRgba*(path: string): ImagePixels =
  var width, height, channels: int
  try:
    result.pixels = stbi.load(path, width, height, channels, stbi.RGBA)
  except stbi.STBIException as err:
    raise newException(ImageLoadError, "failed to load image " & path & ": " & err.msg)
  if width <= 0 or height <= 0 or result.pixels.len != width * height * stbi.RGBA:
    raise newException(ImageLoadError, "invalid image data " & path)
  result.width = width.int32
  result.height = height.int32
