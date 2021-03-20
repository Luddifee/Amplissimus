import 'dart:io';

import 'package:dsbuntis/dsbuntis.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:pedantic/pedantic.dart';
import 'package:update/update.dart';
import '../appinfo.dart';
import '../constants.dart';
import '../dsbapi.dart' as dsb;
import '../logging.dart';
import '../main.dart';
import '../touch_bar.dart';
import '../uilib.dart';
import '../wpemails.dart';
import '../langs/language.dart';
import 'first_login.dart';
import 'settings.dart';

class AmpHomePage extends StatefulWidget {
  AmpHomePage(this.initialIndex, {Key? key}) : super(key: key);
  final int initialIndex;
  @override
  AmpHomePageState createState() => AmpHomePageState();
}

ScaffoldMessengerState? scaffoldMessanger;
final refreshKey = GlobalKey<RefreshIndicatorState>();

var checkForUpdates = !Platform.isAndroid;

class AmpHomePageState extends State<AmpHomePage>
    with SingleTickerProviderStateMixin {
  late TabController tabController;

  void checkBrightness() {
    if (!prefs.useSystemTheme) return;
    prefs.brightness = SchedulerBinding.instance!.window.platformBrightness;
    Future.delayed(Duration(milliseconds: 150), rebuild);
    Future.delayed(Duration(milliseconds: 150), rebuildWholeApp);
  }

  @override
  void initState() {
    ampInfo('AmpHomePageState', 'initState()');
    if (SchedulerBinding.instance != null) checkBrightness();
    SchedulerBinding.instance?.window.onPlatformBrightnessChanged =
        checkBrightness;
    super.initState();
    tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialIndex);
    prefs.timerInit(() => rebuildDragDown());
    initTouchBar(tabController);
    (() async {
      if (!checkForUpdates || !prefs.updatePopup) return;
      ampInfo('UN', 'Searching for updates...');
      checkForUpdates = false;
      final update = await UpdateInfo.getFromGitHub(
        Constants.GITHUB_URI,
        await appVersion,
        http.get,
      );
      if (update != null) {
        ampInfo('UN', 'Found an update, displaying the dialog.');
        final old = await appVersion;
        await ampDialog(
          context,
          title: Language.current.update,
          children: (_, __) =>
              [ampText(Language.current.plsUpdate(old, update.version))],
          actions: (alCtx) => [
            ampDialogButton(Language.current.dismiss, Navigator.of(alCtx).pop),
            ampDialogButton(
                Language.current.open, () => ampOpenUrl(update.url)),
          ],
          widgetBuilder: ampColumn,
        );
      }
    })();
  }

  void rebuild() {
    try {
      setState(() {});
      ampInfo('AmpApp', 'rebuilt!');
    } catch (e) {
      ampInfo('AmpHomePageState.rebuild', errorString(e));
    }
  }

  Future<Null> rebuildDragDown() async {
    unawaited(refreshKey.currentState?.show());
    final d = dsb.updateWidget();
    await wpemailUpdate();
    await d;
    rebuild();
  }

  int _lastUpdate = 0;
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Constants.COLOR_ACCENT));
    try {
      ampInfo('AmpHomePageState', 'Building HomePage...');
      scaffoldMessanger = ScaffoldMessenger.of(context);
      if (_lastUpdate <
          DateTime.now()
              .subtract(Duration(minutes: prefs.timer))
              .millisecondsSinceEpoch) {
        rebuildDragDown();
        _lastUpdate = DateTime.now().millisecondsSinceEpoch;
      }
      final tabs = [
        RefreshIndicator(
          key: refreshKey,
          onRefresh: rebuildDragDown,
          child: ListView(
            children: [
              dsb.widget,
              wpemailsave.isNotEmpty ? Divider(height: 20) : ampNull,
              wpemailsave.isNotEmpty ? wpemailWidget() : ampNull,
            ],
          ),
        ),
        Settings(this),
      ];

      return SafeArea(
        child: Scaffold(
          appBar: AmpTabBar(
            [
              Tab(text: Language.current.start),
              Tab(text: Language.current.settings),
            ],
            tabController,
          ),
          body: TabBarView(
            controller: tabController,
            physics: ClampingScrollPhysics(),
            children: tabs,
          ),
        ),
      );
    } catch (e) {
      ampErr('AmpHomePageState', errorString(e));
      return ampText(errorString(e));
    }
  }
}
