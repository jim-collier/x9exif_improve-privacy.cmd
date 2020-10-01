# x9exif_improve-privacy.cmd
Uses exiftool on Windows to remove invalid and/or privacy-sensitive fields from images.

## Features

- Retains creator/copyright information.
- Removes invalid, custom, and non-standard tags.
- Removes fields that, in aggregate, might be considered security and/or privacy risks, such as:
  - GPS coordinates
  - Camera make, model, and lens data
- Works on EXIF, XMP, IPTC, and other forms of metadata.
- Relies on the outstanding free program [`exiftool`](https://exiftool.org/) by Phil Harvey.

## Notes

- This could easily be ported to (or rewritten in) Bash, since `exiftool` itself is cross-platform.
- Exiftool is not included, for reasons of potentially incompatible licenses. It is is inarguably, currently, the best FLOSS software (or software period) for managing image metadata. Exiftool itslef is licensed under [GPLv1](https://dev.perl.org/licenses/gpl1.html). Go get it now, [here](https://exiftool.org/).
  - All you have to do is download it, extract it somewhere in your system or user path, and rename the single executable (as is officially recommended) to `exiftool.exe`.
