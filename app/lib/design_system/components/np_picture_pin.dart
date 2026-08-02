import 'package:flutter/material.dart';

import '../tokens/design_tokens.g.dart';

/// A map pin whose face is a photograph.
///
/// Round rather than the teardrop of [NpMapPin], and that difference is the
/// point: a player scanning the map can tell "somewhere I photographed" from
/// "somewhere that exists" without reading anything.
class NpPicturePin extends StatelessWidget {
  const NpPicturePin({
    required this.image,
    this.size = NpSize.mapPin,
    this.borderColor = NpColors.accentDefault,
    super.key,
  });

  /// Already resized for this pin — see `PicturePointThumbnails`. A full-size
  /// camera image here would decode at full resolution on every rebuild.
  final ImageProvider<Object>? image;

  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NpColors.backgroundPanel,
        border: Border.all(color: borderColor, width: NpBorderWidth.thick),
        boxShadow: const [NpShadows.marker],
        image: image == null
            ? null
            : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      // Shown while the file is missing or still decoding, so a photo point is
      // never an empty hole on the map.
      child: image != null
          ? null
          : Icon(
              Icons.photo_camera_outlined,
              size: size * 0.5,
              color: NpColors.contentMuted,
            ),
    );
  }
}
