# Ponos — Logo & Branding Reference

**Place this folder at `docs/design/branding/`.** The ZIP contains only the `branding/` folder so it can be dropped into the existing `docs/design/` hierarchy.

The approved **graphic-only Ponos logo** has symmetrical gold laurel branches,
a central ascending mountain, an enclosing gold arc and a small lower star.
The launcher uses the supplied gold emblem on the Ponos light surface
`AppColors.surfaceTinted` (`#EAF1F8`). In-app headers use the supplied
transparent emblem, tinted muted bronze `AppColors.brandBronze` (`#98723D`),
directly on the existing surface. The app name stays separate as UI text.
The original near-black artwork and previews remain historical references.

## Folder contents

```text
branding/
├── README.md                       # this entry point
├── design_rules.md                 # non-negotiable visual/placement requirements
├── implementation_handoff.md      # self-contained instructions for Codex
├── branding.spec.json             # machine-readable asset map
├── reference/
│   └── approved_logo_original.png # original approved image, untouched (1254 px)
├── assets/
│   ├── app_icon_1024.png           # full-resolution Android launcher source
│   ├── app_icon_512.png            # alternative square export
│   ├── app_icon_192.png            # smaller/web source if needed
│   ├── app_icon_48.png             # small-size reference
│   ├── header_logo_512.png         # historical dark-background header export
│   ├── transparent_emblem_1024.png # gold-only, transparent pixels around it
│   ├── ponos_logo_surface_1024.png  # emblem composited on the Ponos surface
│   ├── android_adaptive_background_surface_432.png
│   ├── android_adaptive_foreground_432.png
│   └── android_adaptive_background_432.png
└── preview/
    ├── icon_size_comparison.png    # launcher, header, compact and adaptive examples
    └── header_placement_reference.png # conceptual header reference
```

## Instructions for the implementer

1. Read `design_rules.md`, inspect `reference/approved_logo_original.png` and both images under `preview/`.
2. Locate the actual Flutter asset and launcher-icon configuration in this repository; don't assume a specific generator/package.
3. Use the supplied transparent emblem for in-app headers with the bronze tint;
   retain the gold-on-`#EAF1F8` launcher variants. Copy required assets into
   the app; **do not reference `docs/design/` at runtime.**
4. Replace (a) the phone's Android launcher icon, (b) shared top-left branding on mobile and desktop/web, and (c) any old in-app main-menu logo. Preserve the existing separate `Ponos` text label.
5. Rebuild the Android app for launcher-icon changes. Flutter hot reload alone does not update OS launcher icons.
6. Review at actual rendered sizes (particularly 32–48 px header logo), on multiple screen sizes; do not assume original-artwork visibility at tiny sizes.

See `implementation_handoff.md` for an immediately reusable Codex task.
