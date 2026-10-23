import 'package:flutter/widgets.dart';

import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';

String familySortKey(String name) => throw UnimplementedError('familySortKey');

int compareTopLevel(MemberFamily a, MemberFamily b) =>
    throw UnimplementedError('compareTopLevel');

int compareChildren(MemberFamily a, MemberFamily b) =>
    throw UnimplementedError('compareChildren');

class FamilyMenuRow {
  const FamilyMenuRow(this.family, this.depth);
  final MemberFamily family;
  final int depth;
}

List<FamilyMenuRow> nestFamilies(List<MemberFamily> families) =>
    throw UnimplementedError('nestFamilies');

class FamilyIndentGuide extends StatelessWidget {
  const FamilyIndentGuide({
    super.key,
    required this.depth,
    required this.height,
  });

  final int depth;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (depth <= 0) return const SizedBox.shrink();
    return SizedBox(
      width: 24.0 * depth,
      height: height,
      child: const ColoredBox(color: albumSage),
    );
  }
}
