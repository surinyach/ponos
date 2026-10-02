/// Centralized paths for Ponos production assets.
abstract final class AppAssets {
  static const interVariable =
      'assets/fonts/inter/Inter-VariableFont_opsz,wght.ttf';
  static const interItalicVariable =
      'assets/fonts/inter/Inter-Italic-VariableFont_opsz,wght.ttf';

  static const ponosEmblemFull = 'assets/branding/ponos_emblem_full.svg';
  static const ponosEmblemCompact = 'assets/branding/ponos_emblem_compact.svg';

  static const dividerPrimary = 'assets/decorative/divider_primary.svg';
  static const dividerAccent = 'assets/decorative/divider_accent.svg';
  static const greekPillar = 'assets/decorative/greek_pillar.svg';

  static const appCanvasMobile = 'assets/backgrounds/app_canvas_mobile.svg';
  static const appCanvasDesktop = 'assets/backgrounds/app_canvas_desktop.svg';
  static const architecturalHeroMobile =
      'assets/backgrounds/architectural_hero_mobile.svg';
  static const architecturalHeroDesktop =
      'assets/backgrounds/architectural_hero_desktop.svg';
  static const focusAmbienceMobile =
      'assets/backgrounds/focus_ambience_mobile.svg';
  static const focusAmbienceDesktop =
      'assets/backgrounds/focus_ambience_desktop.svg';

  static const emptyFocusAreas = 'assets/illustrations/empty_focus_areas.svg';
  static const emptyFocusSession =
      'assets/illustrations/empty_focus_session.svg';
  static const emptyWorkLog = 'assets/illustrations/empty_work_log.svg';
  static const emptySpecialActivities =
      'assets/illustrations/empty_special_activities.svg';

  static const branding = [ponosEmblemFull, ponosEmblemCompact];
  static const decorative = [dividerPrimary, dividerAccent, greekPillar];
  static const backgrounds = [
    appCanvasMobile,
    appCanvasDesktop,
    architecturalHeroMobile,
    architecturalHeroDesktop,
    focusAmbienceMobile,
    focusAmbienceDesktop,
  ];
  static const illustrations = [
    emptyFocusAreas,
    emptyFocusSession,
    emptyWorkLog,
    emptySpecialActivities,
  ];
  static const all = [
    ...branding,
    ...decorative,
    ...backgrounds,
    ...illustrations,
  ];
}
