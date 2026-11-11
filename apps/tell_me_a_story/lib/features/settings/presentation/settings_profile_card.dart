part of 'settings_page.dart';

/// Form values and callbacks of the "Your profile" card.
class SettingsProfileForm {
  const SettingsProfileForm({
    required this.name,
    required this.about,
    required this.email,
    required this.displayName,
    required this.preview,
    required this.birth,
    required this.birthEpoch,
    required this.visibility,
    required this.saving,
    required this.savedNotice,
    required this.onPick,
    required this.onBirthChanged,
    required this.onVisibility,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController name;
  final TextEditingController about;
  final TextEditingController email;
  final String? displayName;
  final Uint8List? preview;
  final StoryDate? birth;
  final int birthEpoch;
  final BirthVisibility visibility;
  final bool saving;
  final bool savedNotice;
  final VoidCallback onPick;
  final ValueChanged<StoryDate?> onBirthChanged;
  final ValueChanged<BirthVisibility> onVisibility;
  final VoidCallback onCancel;
  final VoidCallback onSave;
}

/// The bordered "Your profile" card: photo, name, birth, about, email, Save.
class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard({super.key, required this.form});

  final SettingsProfileForm form;

  @override
  Widget build(BuildContext context) {
    const strong = Divider(height: 1, color: Color(0xFFE8DFD5));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8DFD5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardHeading(),
            const SizedBox(height: 22),
            strong,
            const SizedBox(height: 24),
            Text('PROFILE PHOTO', style: _kicker),
            const SizedBox(height: 10),
            _PhotoRow(form: form),
            const SizedBox(height: 28),
            _NameBlock(controller: form.name),
            const _SoftGap(),
            _BirthBlock(form: form),
            const _SoftGap(),
            _AboutBlock(controller: form.about),
            const _SoftGap(),
            _EmailBlock(controller: form.email),
            const SizedBox(height: 22),
            strong,
            const SizedBox(height: 16),
            _Actions(form: form),
          ],
        ),
      ),
    );
  }
}

/// 22px, a soft rule, 22px between profile fields.
class _SoftGap extends StatelessWidget {
  const _SoftGap();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Divider(height: 1, color: Color(0xB3E8DFD5)),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF5DED6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.badge_outlined,
            size: 18,
            color: albumTerracotta,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your profile',
                style: GoogleFonts.newsreader(
                  color: albumInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.form});

  final SettingsProfileForm form;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _AvatarWell(displayName: form.displayName, preview: form.preview),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ReplacePhotoButton(
                    onPressed: form.saving ? null : form.onPick,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarWell extends StatelessWidget {
  const _AvatarWell({required this.displayName, required this.preview});

  final String? displayName;
  final Uint8List? preview;

  @override
  Widget build(BuildContext context) {
    final initials = profileInitials(displayName);
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFAF2EB),
              border: Border.all(color: const Color(0xFFD8C7B8), width: 2),
            ),
            child: ProfileAvatar(
              size: 86,
              displayName: displayName,
              bytes: preview,
            ),
          ),
          if (preview != null && initials.isNotEmpty)
            Positioned(
              right: 0,
              bottom: 0,
              child: _InitialsBadge(initials: initials),
            ),
        ],
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: albumTerracotta,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        initials,
        style: GoogleFonts.sourceSans3(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReplacePhotoButton extends StatelessWidget {
  const _ReplacePhotoButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('settings-upload'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: albumTerracotta,
        backgroundColor: const Color(0x80F5DED6),
        side: BorderSide(color: albumTerracotta.withValues(alpha: 0.2)),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.photo_camera_outlined, size: 14),
      label: const Text(
        'Replace photo',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('NAME', style: _kicker),
            Text(
              ' *',
              style: _kicker.copyWith(color: albumTerracotta, letterSpacing: 0),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('settings-name'),
          controller: controller,
          style: _field,
          decoration: _decoration,
        ),
      ],
    );
  }
}

class _BirthBlock extends StatelessWidget {
  const _BirthBlock({required this.form});

  final SettingsProfileForm form;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: albumTerracotta,
                ),
                const SizedBox(width: 6),
                Text('DATE OF BIRTH', style: _kicker),
                const SizedBox(width: 6),
                Text('(optional)', style: _hint),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        PersonDateField(
          key: ValueKey('settings-birth-${form.birthEpoch}'),
          label: 'Date of birth',
          showLabel: false,
          initial: form.birth,
          onChanged: form.onBirthChanged,
        ),
        const SizedBox(height: 12),
        _VisibilityChoice(form: form),
      ],
    );
  }
}

class _VisibilityChoice extends StatelessWidget {
  const _VisibilityChoice({required this.form});

  final SettingsProfileForm form;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('settings-birth-visibility'),
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final option in const [
          (BirthVisibility.hidden, 'Hidden'),
          (BirthVisibility.year, 'Year only'),
          (BirthVisibility.yearMonth, 'Year and month'),
          (BirthVisibility.full, 'Full date'),
        ])
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: form.visibility == option.$1
                  ? albumTerracotta
                  : albumInk,
              backgroundColor: form.visibility == option.$1
                  ? albumSage.withValues(alpha: 0.25)
                  : albumParchment,
            ),
            onPressed: form.saving ? null : () => form.onVisibility(option.$1),
            child: Text(option.$2),
          ),
      ],
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final count = controller.text.length;
    final over = count > 500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ABOUT', style: _kicker),
            const SizedBox(width: 6),
            Text('(optional)', style: _hint),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('settings-about'),
          controller: controller,
          minLines: 4,
          maxLines: 4,
          style: _field.copyWith(fontSize: 14, height: 1.45),
          decoration: _decoration,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$count / 500',
            style: _hint.copyWith(color: over ? albumTerracotta : null),
          ),
        ),
      ],
    );
  }
}

class _EmailBlock extends StatelessWidget {
  const _EmailBlock({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ACCOUNT EMAIL', style: _kicker),
        const SizedBox(height: 6),
        TextField(
          key: const Key('settings-email'),
          controller: controller,
          readOnly: true,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.sourceSans3(
            color: const Color(0xFF58504D),
            fontSize: 14,
          ),
          decoration: _decoration.copyWith(
            fillColor: const Color(0xFFF0EAE2),
            suffixIcon: const Icon(Icons.lock_outline, size: 18),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.form});

  final SettingsProfileForm form;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (form.savedNotice)
          const Expanded(child: _SavedNotice())
        else
          const Spacer(),
        TextButton(
          onPressed: form.saving ? null : form.onCancel,
          child: Text(
            'Cancel',
            style: GoogleFonts.sourceSans3(
              color: const Color(0xFF665D5A),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _SaveButton(
          saving: form.saving,
          onPressed: form.saving ? null : form.onSave,
        ),
      ],
    );
  }
}

class _SavedNotice extends StatelessWidget {
  const _SavedNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: albumSage,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'All changes saved to album cloud',
            style: GoogleFonts.sourceSans3(
              color: const Color(0xFF665D5A),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const Key('settings-save'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: albumTerracotta,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      ),
      icon: Icon(saving ? Icons.hourglass_top : Icons.save_outlined, size: 16),
      label: Text(
        saving ? 'Saving...' : 'Save',
        style: GoogleFonts.sourceSans3(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

final _kicker = GoogleFonts.sourceSans3(
  color: const Color(0xFF655E5B),
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.1,
);

final _hint = GoogleFonts.sourceSans3(
  color: const Color(0xFF655E5B),
  fontSize: 11,
);

final _field = GoogleFonts.literata(color: albumInk, fontSize: 16);

const _decoration = InputDecoration(
  filled: true,
  fillColor: albumParchment,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Color(0xFFE4D9C6)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Color(0xFFE4D9C6)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: albumTerracotta),
  ),
);
