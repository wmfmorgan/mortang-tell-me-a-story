part of 'manage_family_page.dart';

const _detailError = Color(0xFF9F403D);
const _detailLine = Color(0xFFB9B0AD);
const _detailVariant = albumInk;

TextStyle get _label => GoogleFonts.sourceSans3(
  color: albumInk,
  fontSize: 14,
  fontWeight: FontWeight.w500,
);

TextStyle get _kicker => GoogleFonts.sourceSans3(
  color: _detailVariant,
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.8,
);

TextStyle get _helper =>
    GoogleFonts.literata(color: _detailVariant, fontSize: 14);

TextStyle get _section => GoogleFonts.newsreader(
  color: albumInk,
  fontSize: 20,
  fontWeight: FontWeight.w700,
);

InputDecoration get _field => InputDecoration(
  isDense: true,
  filled: true,
  fillColor: albumParchment,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: _detailLine.withValues(alpha: 0.4)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: _detailLine.withValues(alpha: 0.4)),
  ),
);

ButtonStyle get _outlineButton => OutlinedButton.styleFrom(
  foregroundColor: albumInk,
  side: BorderSide(color: _detailLine.withValues(alpha: 0.8)),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: _label,
);

ButtonStyle get _quietButton => OutlinedButton.styleFrom(
  foregroundColor: albumInk,
  backgroundColor: const Color(0xFFF5ECE9),
  side: BorderSide(color: _detailLine.withValues(alpha: 0.3)),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  textStyle: _label,
);

String _roleHelp(String role) {
  return switch (role) {
    'owner' => 'Your permission level grants full administrative controls over the family archive.',
    'co_owner' => 'Co-owners have the same powers as the owner.',
    _ =>
      'Family members with access to read and contribute stories to the album.',
  };
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Not found'));
  }
}

/// [left] beside [right], stacked under 720 wide.
class _Split extends StatelessWidget {
  const _Split({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: left),
            const SizedBox(width: 24),
            right,
          ],
        );
      },
    );
  }
}

/// Kicker or section title over a helper line.
class _CardLead extends StatelessWidget {
  const _CardLead({
    required this.title,
    required this.titleStyle,
    required this.helper,
    this.gap = 6,
  });

  final String title;
  final TextStyle titleStyle;
  final String helper;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        SizedBox(height: gap),
        Text(helper, style: _helper),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child, this.borderColor});

  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F6).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? _detailLine.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: albumInk.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(32), child: child),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5DED6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        familyRoleLabel(role),
        style: GoogleFonts.sourceSans3(
          color: const Color(0xFF5E4E48),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PeopleList extends StatelessWidget {
  const _PeopleList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _detailLine.withValues(alpha: 0.2)),
          bottom: BorderSide(color: _detailLine.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: _detailLine.withValues(alpha: 0.2),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Small rounded tag: invite status or a person's role.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.color, this.textColor});

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF5ECE9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.sourceSans3(
          color: textColor ?? _detailVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Text action on a row: Make member, Remove, Resend, Cancel invite.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
    this.color = albumInk,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: color),
      child: Text(
        label,
        style: GoogleFonts.sourceSans3(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
