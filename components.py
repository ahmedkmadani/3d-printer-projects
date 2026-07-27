"""Keepout solids for the components, at their installed positions.

Shared by the enclosure model (to verify nothing collides) and by
validate.py (interference checks). Simple bounding solids, per the brief.
"""

from build123d import Box, Pos, Part

import params as P


def battery() -> Part:
    """503035 max envelope, flat on the interior floor."""
    return Pos(P.BATT_CTR_X, P.BATT_CTR_Y, P.BATT_T / 2) * Box(
        P.BATT_W, P.BATT_L, P.BATT_T
    )


def pcb() -> Part:
    """Bare PCB plate."""
    z = (P.PCB_BACK_Z + P.PCB_FRONT_Z) / 2
    return Pos(0, 0, z) * Box(P.PCB_W, P.PCB_L, P.PCB_T)


def display() -> Part:
    """Display module block: panel outline, from PCB front to panel front."""
    z = (P.PCB_FRONT_Z + P.PANEL_FRONT_Z) / 2
    # panel centered on the active-area center (border differences are inside
    # the block; the block already spans the full panel outline)
    return Pos(P.ACTIVE_CTR_X, P.ACTIVE_CTR_Y, z) * Box(
        P.PANEL_W, P.PANEL_L, P.PANEL_FRONT_Z - P.PCB_FRONT_Z
    )


def back_mid_keepout() -> Part:
    """Small parts under the PCB, over the battery zone."""
    z = P.PCB_BACK_Z - P.BACK_CLEAR_MID / 2
    return Pos(0, 0, z) * Box(P.PCB_W - 4, P.PCB_L - 8, P.BACK_CLEAR_MID)


def usb_keepout() -> Part:
    """USB-C shell on the PCB back face at the -Y edge (plus plug reach)."""
    w, d, h = 9.2, 7.5, 3.4
    return Pos(P.USB_CTR_X, -P.PCB_L / 2 + d / 2 - 1.4, P.PCB_BACK_Z - h / 2) * Box(
        w, d, h
    )


def sd_keepout() -> Part:
    """microSD holder on the PCB back face at the +X edge; card protrudes."""
    w, d, h = 15.0, 14.0, 2.0
    return Pos(P.PCB_W / 2 - w / 2 + 2.0, P.SD_CTR_Y, P.PCB_BACK_Z - h / 2) * Box(
        w, d, h
    )


def speaker() -> Part:
    """Oval speaker unit in its bay beyond the +Y PCB edge."""
    y = P.PCB_L / 2 + P.CLEARANCE + P.SPK_W / 2 + 1.0
    return Pos(P.SPK_CTR_X, y, 4.5) * Box(P.SPK_L, P.SPK_W, 9.0)


def switches() -> list[Part]:
    """Side tactile switch bodies on the PCB back, +X edge."""
    out = []
    for y in (P.BTN1_CTR_Y, P.BTN2_CTR_Y):
        out.append(
            Pos(P.PCB_W / 2 - 2.0, y, P.BTN_CTR_Z) * Box(4.0, 4.5, 2.6)
        )
    return out


def all_components() -> dict[str, Part]:
    d = {
        "battery": battery(),
        "pcb": pcb(),
        "display": display(),
        "back_mid": back_mid_keepout(),
        "usb": usb_keepout(),
        "sd": sd_keepout(),
        "speaker": speaker(),
    }
    for i, s in enumerate(switches(), 1):
        d[f"switch{i}"] = s
    return d
