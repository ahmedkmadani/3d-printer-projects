"""Export case 1, each half already in its print orientation."""
import os
from build123d import Mesher, Pos, Rot, export_stl
import params as P
from case1 import build_front, build_back, build_pin

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "models", "next")
os.makedirs(OUT, exist_ok=True)

def write(part, name, note):
    export_stl(part, os.path.join(OUT, f"{name}.stl"), tolerance=0.012,
               angular_tolerance=0.1)
    m = Mesher(); m.add_shape(part); m.write(os.path.join(OUT, f"{name}.3mf"))
    cm3 = part.volume / 1000
    b = part.bounding_box()
    print(f"  {name:16s} {cm3:5.2f} cm3  ~{cm3*(0.55+0.45*0.20)*1.24:4.1f} g  "
          f"{b.size.X:5.2f} x {b.size.Y:5.2f} x {b.size.Z:5.2f}   {note}")

# Two sets. `case1_front`/`case1_back` are the halves as first printed and
# approved — no SD opening. `*_sd_card` add the card slot (back) and the
# tongue relief behind it (front). The printed front is never overwritten.
#
# C1_VARIANT=header writes `case1_back_header` (+ `_sd_card`): 3 mm deeper,
# cell 602535 beside the header. The front and the pins are the plain ones —
# they do not change, so they are not re-exported.
# the slide-lock key: same part for both variants, print 2-3 (it is the
# one fit-tuned part — a loose or tight key reprints in two minutes)
from case1 import build_key
write(build_key(), "case1_key", "flat face down; blocks the slide, pried out by the nail groove")

if P.C1_VARIANT == "header":
    write(build_front(False), "case1_front_header", "window face on the bed; slide-lock tongue, same for either back")
    write(build_back(False), "case1_back_header", "floor on the bed; header fitted, 602535 cell; NO sd slot")
    write(build_back(True), "case1_back_header_sd_card", "floor on the bed; header fitted, 602535 cell; SD slot")
else:
    write(build_front(False), "case1_front", "window face on the bed; NO sd slot (as printed)")
    write(build_back(False), "case1_back", "floor on the bed; NO sd slot")
    write(build_front(True), "case1_front_sd_card", "window face on the bed; tongue relieved for the card")
    write(build_back(True), "case1_back_sd_card", "floor on the bed; SD slot in the +X skin")
    write(build_pin(), "case1_pin_pwr", "flange on the bed; PWR, flat head")
    write(build_pin(True), "case1_pin_rec", "flange on the bed; RECORD, domed, stands 0.4 further out")
print(f"\n  assembled {P.C1_OUT_W:.1f} x {P.C1_OUT_L:.1f} x {P.C1_H:.2f} mm")
