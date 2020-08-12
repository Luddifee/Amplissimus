import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:Amplessimus/day.dart';
import 'package:Amplessimus/dsbutil.dart';
import 'package:Amplessimus/first_login.dart';
import 'package:Amplessimus/main.dart';
import 'package:Amplessimus/utils.dart';
import 'package:Amplessimus/langs/language.dart';
import 'package:Amplessimus/logging.dart';
import 'package:Amplessimus/prefs.dart' as Prefs;
import 'package:Amplessimus/timetables.dart';
import 'package:Amplessimus/uilib.dart';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';

const String _DSB_BUNDLE_ID = 'de.heinekingmedia.dsbmobile';
const String _DSB_DEVICE = 'SM-G950F';
const String _DSB_VERSION = '2.5.9';
const String _DSB_OS_VERSION = '29 10.0';

class DsbSubstitution {
  String affectedClass;
  List<int> hours;
  String teacher;
  String subject;
  String notes;
  bool isFree;

  DsbSubstitution(this.affectedClass, this.hours, this.teacher, this.subject,
      this.notes, this.isFree);

  DsbSubstitution.fromJson(Map<String, dynamic> json)
      : affectedClass = json['affectedClass'],
        hours = List<int>.from(json['hours']),
        teacher = json['teacher'],
        subject = json['subject'],
        notes = json['notes'],
        isFree = json['isFree'];

  Map<String, dynamic> toJson() => {
        'affectedClass': affectedClass,
        'hours': hours,
        'teacher': teacher,
        'subject': subject,
        'notes': notes,
        'isFree': isFree,
      };

  static final _zero = '0'.codeUnitAt(0), _nine = '9'.codeUnitAt(0);

  static List<int> parseIntsFromString(String s) {
    var out = <int>[];
    var lastindex = 0;
    for (var i = 0; i < s.length; i++) {
      var c = s[i].codeUnitAt(0);
      if (c < _zero || c > _nine) {
        if (lastindex != i) out.add(int.parse(s.substring(lastindex, i)));
        lastindex = i + 1;
      }
    }
    out.add(int.parse(s.substring(lastindex, s.length)));
    return out;
  }

  static DsbSubstitution fromStrings(String affectedClass, String hour,
      String teacher, String subject, String notes) {
    if (affectedClass.codeUnitAt(0) == _zero)
      affectedClass = affectedClass.substring(1);
    return DsbSubstitution(
        affectedClass.toLowerCase(),
        parseIntsFromString(hour),
        teacher,
        subject,
        notes,
        teacher.contains('---'));
  }

  static DsbSubstitution fromElements(
      dom.Element affectedClass,
      dom.Element hour,
      dom.Element teacher,
      dom.Element subject,
      dom.Element notes) {
    return fromStrings(_str(affectedClass), _str(hour), _str(teacher),
        _str(subject), _str(notes));
  }

  static DsbSubstitution fromElementArray(List<dom.Element> e) {
    return fromElements(e[0], e[1], e[2], e[3], e[4]);
  }

  static final _tag = RegExp(r'</?.+?>');

  static String _str(dom.Element e) => e.innerHtml.replaceAll(_tag, '').trim();

  @override
  String toString() =>
      "['$affectedClass', $hours, '$teacher', '$subject', '$notes', $isFree]";

  List<int> get actualHours {
    var h = <int>[];
    for (var i = min(hours); i <= max(hours); i++) h.add(i);
    return h;
  }
}

class DsbPlan {
  Day day;
  String date;
  List<DsbSubstitution> subs;

  DsbPlan(this.day, this.subs, this.date);

  DsbPlan.fromJson(Map<String, dynamic> json)
      : day = dayFromInt(json['day']),
        date = json['date'],
        subs = subsFromJson(json['subs']);

  dynamic toJson() => {
        'day': dayToInt(day),
        'date': date,
        'subs': subsToJson(),
      };

  List<Map<String, dynamic>> subsToJson() {
    var lessonsStrings = <Map<String, dynamic>>[];
    for (var sub in subs) lessonsStrings.add(sub.toJson());
    return lessonsStrings;
  }

  static List<DsbSubstitution> subsFromJson(dynamic subsStrings) {
    var subs = <DsbSubstitution>[];
    for (var s in subsStrings) subs.add(DsbSubstitution.fromJson(s));
    return subs;
  }

  @override
  String toString() => '$day: $subs';
}

Future<String> dsbGetData(
  String username,
  String password, {
  String apiEndpoint = 'https://app.dsbcontrol.de/JsonHandler.ashx/GetData',
  bool cachePostRequests = true,
  Future<String> Function(
          Uri url, Object body, String id, Map<String, String> headers,
          {String Function(String) getCache,
          void Function(String, String, Duration) setCache})
      httpPost = httpPost,
  String dsbLanguage = 'de',
  Language lang,
}) async {
  lang ??= Language.current;
  var datetime = DateTime.now().toIso8601String().substring(0, 3) + 'Z';
  var json = '{'
      '"UserId":"$username",'
      '"UserPw":"$password",'
      '"AppVersion":"$_DSB_VERSION",'
      '"Language":"$dsbLanguage",'
      '"OsVersion":"$_DSB_OS_VERSION",'
      '"AppId":"${uuid4}",'
      '"Device":"$_DSB_DEVICE",'
      '"BundleId":"$_DSB_BUNDLE_ID",'
      '"Date":"$datetime",'
      '"LastUpdate":"$datetime"'
      '}';
  try {
    return utf8.decode(
      GZipDecoder().decodeBytes(
        base64.decode(
          jsonDecode(
            await httpPost(
              Uri.parse(apiEndpoint),
              '{'
                  '"req": {'
                  '"Data": "${base64.encode(GZipEncoder().encode(utf8.encode(json)))}", '
                  '"DataType": 1'
                  '}'
                  '}',
              '$apiEndpoint\t$username\t$password',
              {'content-type': 'application/json'},
              getCache: cachePostRequests ? Prefs.getCache : null,
            ),
          )['d'],
        ),
      ),
    );
  } catch (e) {
    ampErr(ctx: 'DSB][dsbGetData', message: errorString(e));
    throw lang.catchDsbGetData(e);
  }
}

Future<List<DsbPlan>> dsbGetAndParse(
  String jsontext, {
  bool cacheGetRequests = true,
  Future<String> Function(Uri url,
          {String Function(String) getCache,
          void Function(String, String, Duration) setCache})
      httpGet = httpGet,
  Language lang,
}) async {
  lang ??= Language.current;
  var json = jsonDecode(jsontext);
  if (json['Resultcode'] != 0) throw json['ResultStatusInfo'];
  json = json['ResultMenuItems'][0]['Childs'][0];
  var plans = <DsbPlan>[];
  for (var plan in json['Root']['Childs']) {
    String url = plan['Childs'][0]['Detail'];
    var title = plan['Title'];
    var rawHtml = await httpGet(
      Uri.parse(url),
      getCache: cacheGetRequests ? Prefs.getCache : null,
    );
    try {
      ampInfo(ctx: 'DSB', message: 'Trying to parse $title...');
      var html = HtmlParser(rawHtml)
          .parse()
          .children
          .first
          .children[1]
          .children; //body
      var planTitle = _searchHtml(html, 'mon_title').innerHtml;
      html = _searchHtml(html, 'mon_list')
          .children
          .first //for some reason <table>s like to contain <tbody>s
          //(just taking first isnt even standard-compliant, but it works rn)
          .children;
      var subs = <DsbSubstitution>[];
      for (var i = 1; i < html.length; i++)
        subs.add(DsbSubstitution.fromElementArray(html[i].children));
      plans.add(DsbPlan(matchDay(planTitle), subs, planTitle));
    } catch (e) {
      ampErr(ctx: 'DSB][dsbGetAllSubs', message: errorString(e));
      plans.add(DsbPlan(
          Day.Null,
          [
            DsbSubstitution('', [0], '', lang.dsbListErrorTitle,
                lang.dsbListErrorSubtitle, true)
          ],
          title));
    }
  }
  return plans;
}

dom.Element _searchHtml(List<dom.Element> rootNode, String className) {
  for (var e in rootNode) {
    if (e.className.contains(className)) return e;
    var found = _searchHtml(e.children, className);
    if (found != null) return found;
  }
  return null;
}

Future<List<DsbPlan>> dsbGetAllSubs(
  String username,
  String password, {
  bool cacheGetRequests = true,
  bool cachePostRequests = true,
  Future<String> Function(Uri url,
          {String Function(String) getCache,
          void Function(String, String, Duration) setCache})
      httpGet = httpGet,
  Future<String> Function(
          Uri url, Object body, String id, Map<String, String> headers,
          {String Function(String) getCache,
          void Function(String, String, Duration) setCache})
      httpPost = httpPost,
  @required String dsbLanguage,
  Language lang,
}) async {
  lang ??= Language.current;
  if (cacheGetRequests || cachePostRequests) Prefs.flushCache();
  var json = await dsbGetData(username, password,
      cachePostRequests: cachePostRequests,
      httpPost: httpPost,
      dsbLanguage: dsbLanguage,
      lang: lang);
  return dsbGetAndParse(json,
      cacheGetRequests: cacheGetRequests, httpGet: httpGet, lang: lang);
}

List<DsbPlan> dsbSearchClass(List<DsbPlan> plans, String stage, String char) {
  stage ??= '';
  char ??= '';
  for (var plan in plans) {
    var subs = <DsbSubstitution>[];
    for (var sub in plan.subs) {
      if (sub.affectedClass.contains(stage) &&
          sub.affectedClass.contains(char)) {
        subs.add(sub);
      }
    }
    plan.subs = subs;
  }
  return plans;
}

List<DsbPlan> dsbSortAllByHour(List<DsbPlan> plans) {
  for (var plan in plans)
    plan.subs.sort((a, b) => max(a.hours).compareTo(max(b.hours)));
  return plans;
}

Widget dsbGetGoodList(
  List<DsbPlan> plans,
  bool oneClassOnly,
  String char,
  String grade,
  int themeId,
) {
  ampInfo(ctx: 'DSB', message: 'Rendering plans: $plans');
  var widgets = <Widget>[];
  for (var plan in plans) {
    var dayWidgets = <Widget>[];
    if (plan.subs.isEmpty) {
      dayWidgets.add(ListTile(
        title: ampText(Language.current.noSubs),
      ));
    }
    var i = 0;
    for (var sub in plan.subs) {
      dayWidgets.add(ListTile(
        title: ampText(Language.current.dsbSubtoTitle(sub)),
        subtitle: ampText(Language.current.dsbSubtoSubtitle(sub)),
        trailing: (char.isEmpty || grade.isEmpty || !oneClassOnly)
            ? ampText(sub.affectedClass)
            : ampNull,
      ));
      if (++i < plan.subs.length) dayWidgets.add(ampDivider);
    }
    widgets.add(ListTile(
      title: Row(children: <Widget>[
        ampText(' ${Language.current.dayToString(plan.day)}', size: 22),
        IconButton(
          icon: ampIcon(Icons.info),
          tooltip: plan.date.split(' ').first,
          onPressed: () {
            homeScaffoldKey.currentState?.showSnackBar(ampSnackBar(plan.date));
          },
        ),
      ]),
    ));
    widgets.add(ampThemedList(ampColumn(dayWidgets), themeId));
  }
  widgets.add(ampPadding(12));
  return Column(mainAxisAlignment: MainAxisAlignment.center, children: widgets);
}

List<DsbPlan> dsbPlans;
Widget dsbWidget;

Future<Null> dsbUpdateWidget(
    {void Function() callback,
    bool cacheGetRequests = true,
    bool cachePostRequests = true,
    bool cacheJsonPlans,
    Future<String> Function(
            Uri url, Object body, String id, Map<String, String> headers,
            {String Function(String) getCache,
            void Function(String, String, Duration) setCache})
        httpPost,
    Future<String> Function(Uri url,
            {String Function(String) getCache,
            void Function(String, String, Duration) setCache})
        httpGet,
    String dsbLanguage,
    String dsbJsonCache,
    String username,
    String password,
    bool oneClassOnly,
    String grade,
    String char,
    int themeId,
    Language lang}) async {
  await Prefs.waitForMutex();
  httpPost ??= FirstLoginValues.httpPostFunc;
  httpGet ??= FirstLoginValues.httpGetFunc;
  cacheJsonPlans ??= Prefs.useJsonCache;
  callback ??= () {};
  dsbLanguage ??= Prefs.dsbLanguage;
  dsbJsonCache ??= Prefs.dsbJsonCache;
  username ??= Prefs.username;
  password ??= Prefs.password;
  lang ??= Language.current;
  oneClassOnly ??= Prefs.oneClassOnly;
  grade ??= Prefs.grade;
  char ??= Prefs.char;
  themeId ??= Prefs.currentThemeId;
  try {
    if (username.isEmpty || password.isEmpty) throw lang.noLogin;
    var useJCache = cacheJsonPlans && dsbJsonCache != null;
    var plans = useJCache
        ? plansFromJson(dsbJsonCache)
        : await dsbGetAllSubs(username, password,
            lang: lang,
            cacheGetRequests: cacheGetRequests,
            cachePostRequests: cachePostRequests,
            httpPost: httpPost,
            httpGet: httpGet,
            dsbLanguage: dsbLanguage);
    if (!useJCache) dsbJsonCache = plansToJson(plans);
    if (oneClassOnly)
      plans = dsbSortAllByHour(dsbSearchClass(plans, grade, char));
    updateTimetableDays(plans);
    dsbWidget = dsbGetGoodList(plans, oneClassOnly, char, grade, themeId);
    dsbPlans = plans;
  } catch (e) {
    ampErr(ctx: 'DSB][dsbUpdateWidget', message: errorString(e));
    dsbWidget = SizedBox(
      child: Container(
        child: ampThemedList(
          ListTile(title: ampText(errorString(e))),
          themeId,
        ),
        padding: EdgeInsets.only(top: 15),
      ),
    );
  }
  callback();
}

String plansToJson(List<DsbPlan> plans) {
  var plansStrings = [];
  for (var plan in plans) plansStrings.add(plan.toJson());
  return jsonEncode(plansStrings);
}

List<DsbPlan> plansFromJson(String jsonPlans) {
  var plans = <DsbPlan>[];
  for (var plan in jsonDecode(jsonPlans)) plans.add(DsbPlan.fromJson(plan));
  return plans;
}
