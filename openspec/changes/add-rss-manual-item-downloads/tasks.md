## Implementation

- [x] Add shared RSS download source detection.
- [x] Add manual RSS item enqueue report/API to `RssEngineRuntime`.
- [x] Add RSS page item selection and manual download controls.
- [x] Add stable UI ids for RSS manual download controls.
- [x] Add focused runtime and widget coverage.

## Validation

- [x] `dart analyze`
- [x] `flutter test test\domain\rss\rss_engine_runtime_test.dart test\ui\rss_page_test.dart test\ui\rss_and_downloads_test.dart`
- [x] `dart run tools\elaina_tool.dart check changed --scope Fast`
- [x] `openspec.cmd validate --all`
