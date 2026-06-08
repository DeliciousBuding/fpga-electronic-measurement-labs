# C301 RGB Controller Deliverables

Generated: 2026-06-08 09:56 Asia/Hong_Kong

Direct-use files are in `files/`:

- `final-rgb-controller-20260608.sof` - Quartus Programmer SOF for Cyclone IV EP4CE15F17C8.
- `rgb-ble-controller-release-0.1.0+2026062409-arm64.apk` - Android arm64 release APK.
- `C301_RGB彩灯蓝牙控制器_综合实验报告_本地验证草稿.pdf` - TeX-formatted PDF report draft, styled after the Chapter 4 lab report.
- `C301_RGB彩灯蓝牙控制器_综合实验报告_本地验证草稿.docx` - DOCX report draft.
- `C301_RGB彩灯蓝牙控制器_综合实验报告.md` - Markdown source.
- `C301_RGB彩灯蓝牙控制器_综合实验报告_TeX排版稿.tex` - TeX source used to generate the formatted PDF.
- `C301_RGB彩灯蓝牙控制器_提交检查清单.md` - final-submission checklist.
- `local-evidence-manifest.*` - local verification evidence index.

GitHub Release:

- https://github.com/fpga-student/fpga-electronic-measurement-labs/releases/tag/c301-rgb-controller-20260608

Verification summary:

- `tools/verify-app.ps1 -AllLocal` passed before APK version bump: analyze clean, Flutter tests 61/61, WebVisualQA, ModelSim, Quartus A&S, report draft, APK quality, evidence manifest.
- Full Quartus compile refreshed the SOF on 2026-06-08 09:52:32: 0 errors, 3 warnings.
- `tools/verify-app.ps1 -SkipAnalyze -SkipTests -ReportDraft -ApkQuality -EvidenceManifest` passed after APK version bump.
- The report PDF was reformatted with the Chapter 4 TeX style and reviewed to remove internal development-only wording.
- APK quality passed: 21.81 MB / 35 MB, version `0.1.0+2026062409`, target ABI `arm64-v8a`.
- No ADB, APK install, personal phone smoke test, or real BLE phone test was run in this packaging step.

Not final-submission complete yet:

- Field evidence is still 0/6 complete. Fill `field-evidence/` with BLE scan, CH9143 connection, LED effects, serial log, waveform, and cover information, then run `tools/verify-app.ps1 -SkipAnalyze -SkipTests -RequireFieldEvidence`.
