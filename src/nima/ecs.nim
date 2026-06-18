type
  Ent* = distinct uint32

proc ent*(id: uint32): Ent = Ent(id)
proc id*(ent: Ent): uint32 = uint32(ent)
proc `==`*(a, b: Ent): bool = uint32(a) == uint32(b)
proc `$`*(ent: Ent): string = $uint32(ent)
