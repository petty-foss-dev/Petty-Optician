"""Renders the petty: Optician app icon: flat teal eyeglasses on cool gray, in the Petty style.

Usage: python3 render_icon.py <output AppIcon.png>   (needs rsvg-convert)
"""
import subprocess
import sys

ACCENT = "#0F7A8A"
# Two rounded lens rims, a bridge, and temples, on the 108-unit Petty icon grid.
RIMS = (
    "M20,44 H48 A4,4 0 0 1 52,48 V58 A12,12 0 0 1 40,70 H30 A12,12 0 0 1 18,58 V46 A2,2 0 0 1 20,44 Z "
    "M24.5,50 V57.5 A6.5,6.5 0 0 0 31,64 H39 A6.5,6.5 0 0 0 45.5,57.5 V50 Z "
    "M60,44 H88 A2,2 0 0 1 90,46 V58 A12,12 0 0 1 78,70 H68 A12,12 0 0 1 56,58 V48 A4,4 0 0 1 60,44 Z "
    "M62.5,50 V57.5 A6.5,6.5 0 0 0 69,64 H77 A6.5,6.5 0 0 0 83.5,57.5 V50 Z"
)
BRIDGE = "M50,47 Q54,42.5 58,47 L58,52 Q54,48 50,52 Z"
TEMPLES = "M13,44 H20 V50 H15 A2,2 0 0 1 13,48 Z M88,44 H95 V48 A2,2 0 0 1 93,50 H88 Z"
GLINT = "M27,52 L33,52 L28,60 Z M65,52 L71,52 L66,60 Z"

SVG = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108" width="1024" height="1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#F7F9FA"/>
      <stop offset="1" stop-color="#E1E7EA"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="1.2" stdDeviation="1.6" flood-color="#0B2A30" flood-opacity="0.16"/>
    </filter>
  </defs>
  <rect width="108" height="108" fill="url(#bg)"/>
  <g transform="translate(54 54) scale(0.95) translate(-54 -57)" filter="url(#shadow)" fill="{ACCENT}">
    <path d="{RIMS}" fill-rule="evenodd"/>
    <path d="{BRIDGE}"/>
    <path d="{TEMPLES}"/>
    <path d="{GLINT}" fill-opacity="0.35"/>
  </g>
</svg>"""

if __name__ == "__main__":
    subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", "-o", sys.argv[1]], input=SVG.encode(), check=True)
