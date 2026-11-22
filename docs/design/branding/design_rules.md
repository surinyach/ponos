# Ponos branding — approved logo rules

## Identity
The approved graphic is a laurel wreath framing a central mountain / ascending effort silhouette, with an arc above and a tiny four-pointed star at the bottom. Launcher icons use the original gold emblem on `AppColors.surfaceTinted` (`#EAF1F8`). In-app headers tint the transparent emblem `AppColors.brandBronze` (`#98723D`) without a background. The mark is **graphic-only**: no letter P, no wordmark, no clock, no extra ornaments.

## What is approved
- Preserve the geometry, proportions and alpha of the supplied transparent emblem. Recolor the in-app header with the approved bronze tint; retain original gold for launcher icons. Do not reconstruct a dark interior.
- Use `assets/ponos_logo_surface_1024.png` as the surface-tile source and the supplied adaptive foreground over `assets/android_adaptive_background_surface_432.png` for Android adaptive icons. The original dark-background files remain historical references.
- Preserve the current `Ponos` heading as **separate UI text** beside the icon in the shared header. The app icon itself never includes text.
- Use the existing rounded-square styling where appropriate, and retain adequate padding so the laurel is not cropped.

## Placement
- **Mobile:** replace the existing top-left Ponos logo in the shared app header. Do not replace the `Ponos` text label; keep it as normal accessible UI text. Also replace the Android launcher icon visible on the phone's home screen/app drawer.
- **Desktop / web:** replace the top-left shared header/sidebar mark wherever the old mark currently appears, maintaining current alignment and responsive sizing.
- **Other main-menu placements:** replace an old logo only where one currently exists; do not introduce a duplicate.

## Avoid
- Do not redraw, trace or alter the geometry of the artwork. Only the specified in-app bronze tint is permitted.
- Do not embed text into the image.
- Do not stretch the artwork or change its aspect ratio.
- Do not add a white border/circle that competes with the dark tile.
- Do not point the runtime to `docs/design/`; copy the chosen production assets into the actual app asset tree and update Flutter registration as necessary.
- This is a branding-only task: no state, API, persistence, timer or navigation changes.
