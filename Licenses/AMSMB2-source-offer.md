# AMSMB2 source availability

This app distribution uses AMSMB2, resolved from:

- Package repository: https://github.com/amosavian/AMSMB2
- Resolved version: 3.0.0
- Resolved revision: fbb1d37880b7e1d7504c6a6dc9371c10ff932bc9

AMSMB2 wraps libsmb2 for SMB2 or SMB3 file operations. The upstream package states that the effective distribution license is GNU Lesser General Public License 2.1 because the package links against libsmb2.

## Source references

- AMSMB2 upstream repository: https://github.com/amosavian/AMSMB2
- libsmb2 upstream repository: https://github.com/sahlberg/libsmb2

## License notice

AMSMB2 is documented here under the GNU Lesser General Public License 2.1. A copy of the LGPL 2.1 is included in VLCKit-LGPL-2.1.txt.

## Distribution note

The upstream AMSMB2 package declares a dynamic-library product and documents that dynamic linking should be preserved for App Store distribution scenarios. If this app is redistributed outside the internal development environment, the distributor should additionally ensure that the delivery model continues to satisfy the LGPL 2.1 obligations that apply to AMSMB2 and its bundled libsmb2 dependency.