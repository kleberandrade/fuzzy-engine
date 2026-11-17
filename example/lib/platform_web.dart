import 'dart:js_interop';

@JS('localStorage.getItem')
external JSString? _read(JSString key);
@JS('localStorage.setItem')
external void _write(JSString key, JSString value);
@JS('window.open')
external JSAny? _open(JSString url, JSString target, JSString features);

String? readPreference(String key) {
  try {
    return _read(key.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

void writePreference(String key, String value) {
  try {
    _write(key.toJS, value.toJS);
  } catch (_) {/* Storage may be blocked. */}
}

bool openExternal(String url) {
  try {
    _open(url.toJS, '_blank'.toJS, 'noopener,noreferrer'.toJS);
    return true;
  } catch (_) {
    return false;
  }
}

@JS('document.documentElement.lang')
external set _pageLanguage(JSString value);
void setPageLanguage(String language) {
  try {
    _pageLanguage = language.toJS;
  } catch (_) {/* Non-DOM runtimes. */}
}
