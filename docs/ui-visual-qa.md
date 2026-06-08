# UI Visual QA Checklist

Use this checklist before demo, report screenshots, or UI-sensitive commits.

## Start Preview

```powershell
cd D:\Code\Quartus
powershell -ExecutionPolicy Bypass -File .\tools\web-preview.ps1 -Restart
```

Open `http://127.0.0.1:7357` in the Codex App in-app browser.

Useful service commands:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\web-preview.ps1 -Status
powershell -ExecutionPolicy Bypass -File .\tools\web-preview.ps1 -Stop
```

Run the repeatable app quality gate after UI changes:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify-app.ps1
powershell -ExecutionPolicy Bypass -File .\tools\verify-app.ps1 -AllLocal
powershell -ExecutionPolicy Bypass -File .\tools\verify-app.ps1 -SkipAnalyze -SkipTests -WebStatus
powershell -ExecutionPolicy Bypass -File .\tools\verify-app.ps1 -SkipAnalyze -SkipTests -WebVisualQA
```

Use `-AllLocal` before handoff or report refreshes when the local preview is already running. It expands to the no-device gate set: Flutter analyze/test, web preview status, WebVisualQA screenshots/perf, FPGA ModelSim simulation, Quartus Analysis & Synthesis, TeX report draft verification, release APK quality verification, and local evidence manifest generation. It explicitly rejects `-DeviceSmoke` and `-Release`, so it will not run ADB, install an APK, bump the app version, or touch deliverable package checks unless `-DeliverablePackage` is passed separately.

Run FPGA protocol simulation after Verilog or protocol-sensitive app changes:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify-app.ps1 -SkipAnalyze -SkipTests -FpgaSim
powershell -ExecutionPolicy Bypass -File .\tools\verify-app.ps1 -SkipAnalyze -SkipTests -QuartusMap
```

`-WebVisualQA` uses an isolated headless Chrome/Edge profile plus Chrome DevTools Protocol to capture `1280x720`, `390x844`, `390x844 after scroll`, `390x844 after scroll down/up return`, `390x844 Scanner`, `390x844 Scanner debug samples`, `390x844 Effect`, `390x844 Scene`, `390x844 Settings`, `460x900`, and `460x900 after scroll` screenshots into `artifacts/web-visual-qa/`. Scanner debug captures append `visualQa=1` so the science-icon sample device button is available even when the web preview is not a Flutter debug build; the flag is used only by the automated QA URL. It validates PNG dimensions, sampled color diversity, browser console/runtime events, that scrolled screenshots differ from the initial screenshots, that the down/up return screenshot is similar to the initial screenshot, that clicked tab screenshots differ from the LED tab, and that Scanner debug samples differ from the Scanner empty state, so blank white pages, failed Flutter Web first paint, broken wheel scrolling, broken scroll restoration, broken bottom navigation, missing Scanner debug preview, `console.error`, `console.assert`, or runtime exceptions become a hard failure. Each viewport also writes a `*.perf.json` file with Chrome `Performance.getMetrics` data plus a short `requestAnimationFrame` cadence sample; the gate uses deliberately broad limits to catch stuck rendering, very long browser tasks, or abnormal frame intervals without overfitting to one machine. The default viewport wait is 18 seconds to tolerate cold Flutter web-server/DDC startup, and blank/too-small Flutter Web startup screenshots are retried before failing. The script uses narrow desktop viewports instead of Chrome mobile emulation because Flutter Web can assert on negative headless keyboard insets under `mobile: true`.

Current constraint: do not use the personal phone for UI or BLE validation. Do not run ADB, APK install, `device-smoke`, phone screenshots, or commands targeting `[REDACTED]:5555` / `[REDACTED]` unless the user explicitly re-authorizes phone testing.

## Viewports

Verify at least:

- Default Codex side panel width.
- Narrow mobile viewport `360x800`.
- Tall mobile viewport around `460x900`.

## Required Checks

### Color Tab

- Top 8 LED dots are visible as a 4x2 grid.
- Dots do not overlap at narrow width.
- The app bar remains visually solid while scrolling; banner/card text must not show through behind the title.
- Brightness slider remains inside the first card.
- RGB sliders do not jump layout while dragging.
- Preset swatches stay fixed size and do not resize on active state.
- Preset swatches should not start nested scale/fade animations on every selection.

### Bottom Navigation

- Bottom bar is icon-only.
- No text labels.
- No wide Material pill appears on press or selected state.
- Active icon uses scale/color only.
- Tiny scroll jitters should not hide the bar; sustained downward scroll hides it, upward scroll or returning to top shows it.

### Scanner Page

- Tap the Bluetooth icon from the app bar to open scan.
- When no device is found, the page shows inline diagnostics:
  - phase
  - scan count
  - FFF0/FFF1/FFF2 protocol status
  - copy snapshot action
- In debug preview, tap the science icon:
  - `CH9143 RGB Controller` is first.
  - `UART-FFF0-LED` is second.
  - both likely targets show the `RGB` badge.
  - regular BLE devices are below likely targets.
  - tapping a sample shows a debug-only snackbar and does not connect hardware.

### Scene Tab

- Tap a scene card and confirm active visual state:
  - emphasized border/background
  - play marker
  - saved check marker does not overlap active marker
- Change a manual control on the Color tab.
- Return to Scene and confirm active scene highlight clears.

### Settings

- Advanced diagnostics are collapsed by default.
- Expanded debug log is bounded to a fixed-height lazy viewport.
- Long log lines stay one-line with ellipsis.

## Pass Criteria

- No red error screen.
- No visible text overlap.
- No clipped button labels.
- No layout jumps during scroll.
- No translucent app bar content bleed during scroll.
- Bottom navigation hides with slide/fade motion, not by abruptly compressing layout height.
- No console errors in the in-app browser.
- `flutter analyze` and `flutter test` pass after UI changes.
- `tools\verify-app.ps1 -SkipAnalyze -SkipTests -WebVisualQA` passes for all eleven automated screenshots; their `*.browser-events.json` logs contain no error-level events, and their `*.perf.json` files pass the broad frame-cadence/runtime budget.
