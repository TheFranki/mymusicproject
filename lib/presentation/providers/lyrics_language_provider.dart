import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, String> kLyricsLanguageCatalog = {
  'es': 'Español',
  'en': 'Inglés',
  'pt': 'Portugués',
  'fr': 'Francés',
  'de': 'Alemán',
  'it': 'Italiano',
  'ja': 'Japonés',
  'ko': 'Coreano',
  'zh-CN': 'Chino (simplificado)',
  'ru': 'Ruso',
  'zh-TW': 'Chino (tradicional)',
  'ar': 'Árabe',
  'he': 'Hebreo',
  'hi': 'Hindi',
  'th': 'Tailandés',
  'vi': 'Vietnamita',
  'id': 'Indonesio',
  'ms': 'Malayo',
  'tl': 'Filipino',
  'tr': 'Turco',
  'pl': 'Polaco',
  'nl': 'Neerlandés',
  'sv': 'Sueco',
  'no': 'Noruego',
  'da': 'Danés',
  'fi': 'Finés',
  'el': 'Griego',
  'uk': 'Ucraniano',
  'cs': 'Checo',
  'hu': 'Húngaro',
  'ro': 'Rumano',
  'bg': 'Búlgaro',
  'ca': 'Catalán',
  'fa': 'Persa',
  'bn': 'Bengalí',
  'ta': 'Tamil',
};

class LyricsLangSettings {
  const LyricsLangSettings({
    this.enabled = const {'es', 'en'},
    this.hideOriginal = true,
    this.showRomanization = true,
    this.customTranslationEnabled = true,
  });

  final Set<String> enabled;
  final bool hideOriginal;
  final bool showRomanization;
  final bool customTranslationEnabled;

  LyricsLangSettings copyWith({
    Set<String>? enabled,
    bool? hideOriginal,
    bool? showRomanization,
    bool? customTranslationEnabled,
  }) => LyricsLangSettings(
    enabled: enabled ?? this.enabled,
    hideOriginal: hideOriginal ?? this.hideOriginal,
    showRomanization: showRomanization ?? this.showRomanization,
    customTranslationEnabled:
        customTranslationEnabled ?? this.customTranslationEnabled,
  );

  bool _hidden(String code, String? songLang) =>
      hideOriginal && songLang != null && code == songLang;

  Map<String, String> visibleFor(String? songLang) => {
    for (final e in kLyricsLanguageCatalog.entries)
      if (enabled.contains(e.key) && !_hidden(e.key, songLang)) e.key: e.value,
  };

  Map<String, String> moreFor(String? songLang) => {
    for (final e in kLyricsLanguageCatalog.entries)
      if (!enabled.contains(e.key) && !_hidden(e.key, songLang)) e.key: e.value,
  };
}

const _kEnabled = 'lyrics_lang_enabled';
const _kHide = 'lyrics_lang_hide_original';
const _kRom = 'lyrics_lang_show_rom';
const _kCustom = 'lyrics_lang_custom_enabled';

final lyricsLangSettingsProvider =
    StateNotifierProvider<LyricsLangNotifier, LyricsLangSettings>(
      (ref) => LyricsLangNotifier(),
    );

class LyricsLangNotifier extends StateNotifier<LyricsLangSettings> {
  LyricsLangNotifier() : super(const LyricsLangSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_kEnabled);
      state = LyricsLangSettings(
        enabled: list == null
            ? state.enabled
            : list.where(kLyricsLanguageCatalog.containsKey).toSet(),
        hideOriginal: p.getBool(_kHide) ?? true,
        showRomanization: p.getBool(_kRom) ?? true,
        customTranslationEnabled: p.getBool(_kCustom) ?? true,
      );
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kEnabled, state.enabled.toList());
      await p.setBool(_kHide, state.hideOriginal);
      await p.setBool(_kRom, state.showRomanization);
      await p.setBool(_kCustom, state.customTranslationEnabled);
    } catch (_) {}
  }

  void toggleLanguage(String code, bool on) {
    final set = {...state.enabled};
    on ? set.add(code) : set.remove(code);
    state = state.copyWith(enabled: set);
    _save();
  }

  void setHideOriginal(bool v) {
    state = state.copyWith(hideOriginal: v);
    _save();
  }

  void setShowRomanization(bool v) {
    state = state.copyWith(showRomanization: v);
    _save();
  }

  void setCustomTranslationEnabled(bool v) {
    state = state.copyWith(customTranslationEnabled: v);
    _save();
  }
}