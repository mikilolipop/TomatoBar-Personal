# Website redesign QA — 2026-10-01

final result: passed

## Visual truth and evidence

Source visual truth: `/Users/dilyar/.codex/generated_images/01a0f546-9c45-7573-88df-8c4378f0e7a1/exec-87f5dd5e-2725-4378-b059-4990ce05ed14.png` (revision of the user's selected second concept). The user's later instruction removes the lower screenshot entirely. The actual source screenshot's natural proportions and the actual app's pixel tomato override distorted or generated assets in the concept.

Implementation: `http://127.0.0.1:4173/`.
Local evidence directory: `/Users/dilyar/Developer/番茄钟项目/Website-Redesign-20261001/`. Evidence images are QA artifacts, not website assets.

- Full-view comparison in a single input: `comparison-desktop-final.png`.
- Focused hero comparison in a single input: `comparison-hero-final.png`.
- Responsive visual comparison: `comparison-responsive-final.png`.
- Source pixels: 1086 × 1448, proportionally normalized to 1440 × 1920. Desktop viewport 1440 × 960 CSS px; implementation full-page capture 1440 × 2008 pixels. Density 1.
- Mobile viewport 390 × 844, full capture 390 × 2384; narrow viewport 320 × 720, full capture 320 × 2631; tablet viewport 768 × 1024, full capture 768 × 2432. Tablet comparison thumbnail is scaled proportionally to 704px; original remains 768px.
- State: light theme, image dialog closed, installation guide collapsed, home route. No mobile visual source was supplied; responsive views are reviewed for hierarchy, legibility, assets and usable interactions.

## Findings and comparison history

No remaining actionable P0/P1/P2 findings.

1. Initial comparison found [P2] weak display typography. Increased desktop hero to 76px, section heading to 58px, brand to 26px and feature heading/body to 25/16px. The final desktop and focused comparisons show the intended strong hierarchy without overflow.
2. Initial mobile capture found [P2] pixel tomato constrained to 22px by inherited grid placement. Reset grid placement at the mobile breakpoint. Final mobile/narrow captures and DOM measurements show the intended 63 × 63px source sprite.
3. Initial mobile interaction review found [P2] small preview-caption touch target. Added 44px caption action area and practical mobile link targets. The full screenshot also remains clickable.
4. The touch-target refinement temporarily exposed mobile navigation that should be hidden, producing [P1] 352px document overflow at a 320px viewport. Increased the mobile override's selector specificity. The final 320/390 captures show only the compact GitHub header link, and document width equals viewport at all four widths.
5. Narrow closing headline left an awkward short last line. Balanced its wrapping and reserved space for the tomato. Final narrow capture shows balanced two-line copy without overlapping the illustration.

The first comparison stayed blocked. The final comparison was performed after fixes and new browser captures; it does not rely on build success alone.

## Required fidelity surfaces

- **Typography:** system Chinese sans family, strong three-line display title, clear section/feature/body hierarchy. Desktop title is 76px; mobile uses the explicit responsive scale. Text wraps without truncation. Remaining differences in antialiasing and exact letter shapes from the raster concept are accepted P3 polish.
- **Spacing/layout:** split hero, three editorial feature columns, pure-text privacy section, blush download strip, compact installation disclosure and acknowledgements. No horizontal overflow at 1440, 768, 390 or 320. Image's natural ratio, lower-image removal and compact installation row are intentional product constraints.
- **Colors:** ivory `#fffaf0`, brown `#412b20`, terracotta `#b34d3d`, muted `#796d60`, blush `#f9e8dd`. No generated texture, CSS artwork or decorative gradients. Focus outlines and reduced-motion behavior are defined. Full browser VoiceOver testing is outside this website pass.
- **Images/assets:** the single main screenshot renders 846.125 × 567.90625 at desktop (ratio 1.4899026, natural 2360/1584 = 1.489899); rounding differences at narrower widths are below 0.00003. No clipping or fixed height. Pixel tomato bytes are copied unchanged from the native asset. Feather library icons are local upstream files with MIT license. No fabricated app UI, hand-drawn SVG substitute or smooth 3D tomato.
- **Copy:** exact hero intent and selected page structure preserved. Product capabilities, local-data claims, OS/chip compatibility, ad-hoc/not-notarized guidance, MIT/upstream attribution and authorized names `nafi`, `Chiwawa`, `ElF` retained. No fabricated ratings, testimonials or adoption numbers.

## Interactions and checks

- Image preview opens from the screenshot/caption. Escape and Close return focus to the trigger and unlock scrolling. The modal fits the 320px viewport; original-image link is available for detailed viewing.
- Installation links expand the guide. The disclosure can collapse, its visible and accessible label changes together, and direct `#install` navigation opens it after reload.
- Clicking Copy shows success for the public installation command. The website never executes that command.
- Both DMG buttons and ZIP links point to the actual latest v3.9.2 assets. GitHub's live release metadata was checked against every static fallback. The script refreshes all downloads/version labels together only when both valid packages are present, and retains static links on API failure.
- Browser error/warning logs were empty after desktop and narrow-screen interactions. All local image/style/script files exist. JavaScript syntax and whitespace checks pass.
- Repository domain baseline: 214 checks passed. Native app code is unchanged; native app UI acceptance is not inferred from website checks.

## Implementation checklist

All identified P0/P1/P2 items resolved, recaptured and compared. Commit, publish via the existing Pages workflow, and verify the live HTTPS page before claiming deployment complete.

## Follow-up polish

P3: raster-generated typography and artwork can differ slightly from real system fonts and source images. Actual native screenshot dimensions and the user's requested source pixel art take precedence. No P3 blocks release.
