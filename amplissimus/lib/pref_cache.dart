import 'dart:convert';
import 'dart:io';

import 'package:mutex/mutex.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CachedSharedPreferences {
  SharedPreferences _prefs;
  RandomAccessFile _prefFile;
  Mutex _prefFileMutex = Mutex();
  List<String> _editsString = [];
  List<String> _editsInt = [];
  List<String> _editsDouble = [];
  List<String> _editsBool = [];
  List<String> _editsStrings = [];
  Map<String, String> _cacheString = {};
  Map<String, int> _cacheInt = {};
  Map<String, double> _cacheDouble = {};
  Map<String, bool> _cacheBool = {};
  Map<String, List<String>> _cacheStrings = {};

  bool _platformSupportsSharedPrefs;

  Future<Null> setString(String key, String value) async {
    await _prefFileMutex.acquire();
    _cacheString[key] = value;
    _prefFileMutex.release();
    if (_prefs != null)
      await _prefs.setString(key, value);
    else if (_prefFile == null) _editsString.add(key);
    flush();
  }

  Future<Null> setInt(String key, int value) async {
    await _prefFileMutex.acquire();
    _cacheInt[key] = value;
    _prefFileMutex.release();
    if (_prefs != null)
      await _prefs.setInt(key, value);
    else if (_prefFile == null) _editsInt.add(key);
    flush();
  }

  Future<Null> setDouble(String key, double value) async {
    await _prefFileMutex.acquire();
    _cacheDouble[key] = value;
    _prefFileMutex.release();
    if (_prefs != null)
      await _prefs.setDouble(key, value);
    else if (_prefFile == null) _editsDouble.add(key);
    flush();
  }

  Future<Null> setStringList(String key, List<String> value) async {
    await _prefFileMutex.acquire();
    _cacheStrings[key] = value;
    _prefFileMutex.release();
    if (_prefs != null)
      await _prefs.setStringList(key, value);
    else if (_prefFile == null) _editsStrings.add(key);
    flush();
  }

  Future<Null> setBool(String key, bool value) async {
    await _prefFileMutex.acquire();
    _cacheBool[key] = value;
    _prefFileMutex.release();
    if (_prefs != null)
      await _prefs.setBool(key, value);
    else if (_prefFile != null)
      flush();
    else
      _editsBool.add(key);
  }

  int getInt(String key, int defaultValue) {
    if (_cacheInt.containsKey(key)) return _cacheInt[key];
    if (_prefs == null) {
      if (_platformSupportsSharedPrefs)
        throw 'PREFSI NOT INITIALIZED, THIS IS A SEVERE CODE BUG';
      else
        return defaultValue;
    }
    int i = _prefs.getInt(key);
    if (i == null) i = defaultValue;
    return i;
  }

  double getDouble(String key, double defaultValue) {
    if (_cacheDouble.containsKey(key)) return _cacheDouble[key];
    if (_prefs == null) {
      if (_platformSupportsSharedPrefs)
        throw 'PREFSD NOT INITIALIZED, THIS IS A SEVERE CODE BUG';
      else
        return defaultValue;
    }
    double d = _prefs.getDouble(key);
    if (d == null) d = defaultValue;
    return d;
  }

  String getString(String key, String defaultValue) {
    if (_cacheString.containsKey(key)) return _cacheString[key];
    if (_prefs == null) {
      if (_platformSupportsSharedPrefs)
        throw 'PREFSS NOT INITIALIZED, THIS IS A SEVERE CODE BUG';
      else
        return defaultValue;
    }
    String s = _prefs.getString(key);
    if (s == null) s = defaultValue;
    return s;
  }

  bool getBool(String key, bool defaultValue) {
    if (_cacheBool.containsKey(key)) return _cacheBool[key];
    if (_prefs == null) {
      if (_platformSupportsSharedPrefs)
        throw 'PREFSB NOT INITIALIZED, THIS IS A SEVERE CODE BUG';
      else
        return defaultValue;
    }
    bool b = _prefs.getBool(key);
    if (b == null) b = defaultValue;
    return b;
  }

  List<String> getStringList(String key, List<String> defaultValue) {
    if (_cacheStrings.containsKey(key)) return _cacheStrings[key];
    if (_prefs == null) {
      if (_platformSupportsSharedPrefs)
        throw 'PREFSSL NOT INITIALIZED, THIS IS A SEVERE CODE BUG';
      else
        return defaultValue;
    }
    List<String> s = _prefs.getStringList(key);
    if (s == null) s = defaultValue;
    return s;
  }

  void flush() async {
    if (_prefFile != null) {
      await _prefFileMutex.acquire();
      await _prefFile.setPosition(0);
      await _prefFile.truncate(0);
      List<dynamic> prefs = [];
      for (var k in _cacheString.keys)
        if (_cacheString[k] != null)
          prefs.add({"k": k, "v": _cacheString[k], "t": 0});
      for (var k in _cacheInt.keys)
        if (_cacheInt[k] != null)
          prefs.add({"k": k, "v": _cacheInt[k], "t": 1});
      for (var k in _cacheDouble.keys)
        if (_cacheDouble[k] != null)
          prefs.add({"k": k, "v": _cacheDouble[k], "t": 2});
      for (var k in _cacheBool.keys)
        if (_cacheBool[k] != null)
          prefs.add({"k": k, "v": _cacheBool[k] ? 1 : 0, "t": 3});
      for (var k in _cacheStrings.keys)
        if (_cacheStrings[k] != null)
          prefs.add({"k": k, "v": _cacheStrings[k], "t": 4});
      await _prefFile.writeString(jsonEncode(prefs));
      await _prefFile.flush();
      _prefFileMutex.release();
    }
  }

  Future<Null> ctor() async {
    try {
      _platformSupportsSharedPrefs = !Platform.isWindows && !Platform.isLinux;
    } catch (e) {
      //it should only fail on web
      _platformSupportsSharedPrefs = true;
    }
    if (_platformSupportsSharedPrefs) {
      _prefs = await SharedPreferences.getInstance();
      for (String key in _editsString) setString(key, _cacheString[key]);
      for (String key in _editsInt) setInt(key, _cacheInt[key]);
      for (String key in _editsDouble) setDouble(key, _cacheDouble[key]);
      for (String key in _editsBool) setBool(key, _cacheBool[key]);
      for (String key in _editsStrings) setStringList(key, _cacheStrings[key]);
      _editsString.clear();
      _editsInt.clear();
      _editsDouble.clear();
      _editsBool.clear();
      _editsStrings.clear();
    } else {
      await _prefFileMutex.acquire();
      _prefFile =
          await File('.amplissimus_prealpha_data').open(mode: FileMode.append);
      if (await _prefFile.length() > 1) {
        await _prefFile.setPosition(0);
        var bytes = await _prefFile.read(await _prefFile.length());
        //this kind of creates a race condition, but that doesn't really matter lol
        for (dynamic json in jsonDecode(utf8.decode(bytes))) {
          dynamic key = json['k'];
          dynamic val = json['v'];
          dynamic typ = json['t'];
          if (typ == 0)
            _cacheString[key] = val;
          else if (typ == 1)
            _cacheInt[key] = val;
          else if (typ == 2)
            _cacheDouble[key] = val;
          else if (typ == 3)
            _cacheBool[key] = val == 1;
          else if (typ == 4) {
            _cacheStrings[key] = [];
            for (dynamic s in val) _cacheStrings[key].add(s);
          } else
            throw 'Prefs doesn\'t know the pref type "$typ".';
        }
      }
      _prefFileMutex.release();
    }
  }

  void clear() {
    _prefFileMutex.acquire();
    _cacheBool.clear();
    _cacheDouble.clear();
    _cacheInt.clear();
    _cacheString.clear();
    _cacheStrings.clear();
    _prefFileMutex.release();
    if (_prefs == null) {
      if (_platformSupportsSharedPrefs)
        throw 'PREFS NOT LODADA D A D AD';
      else
        return;
    }
    _prefs.clear();
  }
}
