import 'package:Amplissimus/dsbapi.dart';
import 'package:Amplissimus/json.dart';
import 'package:Amplissimus/logging.dart';
import 'package:Amplissimus/main.dart';
import 'package:Amplissimus/prefs.dart' as Prefs;
import 'package:Amplissimus/uilib.dart';
import 'package:Amplissimus/values.dart';
import 'package:Amplissimus/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../animations.dart';

class DevOptionsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        child: MaterialApp(
          builder: (context, child) =>
              ScrollConfiguration(behavior: MyBehavior(), child: child),
          title: AmpStrings.appTitle,
          theme: ThemeData(
            canvasColor: AmpColors.materialColorBackground,
            primarySwatch: AmpColors.materialColorForeground,
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          home: DevOptionsScreenPage(
            title: AmpStrings.appTitle,
          ),
        ),
        onWillPop: () async {
          dsbUpdateWidget(() {});
          Animations.changeScreenEaseOutBackReplace(
              MyApp(initialIndex: 2), context);
          return false;
        });
  }
}

class DevOptionsScreenPage extends StatefulWidget {
  DevOptionsScreenPage({this.title});
  final String title;
  @override
  State<StatefulWidget> createState() => DevOptionsScreenPageState();
}

class DevOptionsScreenPageState extends State<DevOptionsScreenPage>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    DevOptionsValues.tabController =
        TabController(length: 2, vsync: this, initialIndex: 1);
    DevOptionsValues.tabController.animation.addListener(() {
      if (DevOptionsValues.tabController.index < 1) {
        Animations.changeScreenNoAnimationReplace(
            MyApp(
              initialIndex: 2,
            ),
            context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TabBarView(controller: DevOptionsValues.tabController, children: [
      MyApp(initialIndex: 2),
      Scaffold(
        backgroundColor: AmpColors.colorBackground,
        appBar: AppBar(
          centerTitle: true,
          title: Text('Entwickleroptionen',
              style: TextStyle(fontSize: 20, color: AmpColors.colorForeground)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          color: AmpColors.colorBackground,
          margin: EdgeInsets.all(16),
          child: Center(
            child: ListView(
              children: [
                Divider(
                    color: AmpColors.colorForeground,
                    height: Prefs.subListItemSpace + 2),
                ampSwitchWithText(
                  text: 'Entwickleroptionen aktiviert',
                  value: Prefs.devOptionsEnabled,
                  onChanged: (value) =>
                      setState(() => Prefs.devOptionsEnabled = value),
                ),
                Divider(
                  color: AmpColors.colorForeground,
                  height: Prefs.subListItemSpace,
                ),
                ampSwitchWithText(
                  text: 'Hilfe für Langeweile aktiviert',
                  value: Prefs.counterEnabled,
                  onChanged: (value) =>
                      setState(() => Prefs.counterEnabled = value),
                ),
                ampSwitchWithText(
                  text: 'App schließt bei zurück-Taste',
                  value: Prefs.closeAppOnBackPress,
                  onChanged: (value) =>
                      setState(() => Prefs.closeAppOnBackPress = value),
                ),
                ampSwitchWithText(
                  text: 'Dauerhafter Ladebalken',
                  value: Prefs.loadingBarEnabled,
                  onChanged: (value) =>
                      setState(() => Prefs.loadingBarEnabled = value),
                ),
                ampSwitchWithText(
                  text: 'JSON Cache benutzen',
                  value: Prefs.useJsonCache,
                  onChanged: (value) {
                    Prefs.useJsonCache = value;
                    dsbUpdateWidget(() => setState(() {}),
                        cacheJsonPlans: value);
                  },
                ),
                Divider(
                    color: AmpColors.colorForeground,
                    height: Prefs.subListItemSpace),
                ListTile(
                  title: Text('Listenelementabstand',
                      style: AmpColors.textStyleForeground),
                  trailing: Text('${Prefs.subListItemSpace}',
                      style: AmpColors.textStyleForeground),
                  onTap: () => showInputSubListItemSpacingDialog(context),
                ),
                ListTile(
                  title: Text('Refreshtimer (in Minuten)',
                      style: AmpColors.textStyleForeground),
                  trailing: Text('${Prefs.timer}',
                      style: AmpColors.textStyleForeground),
                  onTap: () => showInputTimerDialog(context),
                ),
                Divider(
                    color: AmpColors.colorForeground,
                    height: Prefs.subListItemSpace),
                Divider(color: Colors.transparent, height: 10),
                RaisedButton(
                    child: Text('Print Cache'), onPressed: Prefs.listCache),
                RaisedButton(
                  child: Text('Cache leeren'),
                  onPressed: () => Prefs.clearCache(),
                ),
                RaisedButton.icon(
                  color: Colors.red,
                  icon: Icon(Icons.delete, color: AmpColors.colorForeground),
                  label: Text('App-Daten löschen',
                      style: TextStyle(color: AmpColors.colorForeground)),
                  onPressed: () {
                    showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('App-Daten löschen',
                                style: AmpColors.textStyleForeground),
                            content: Text('Löschen der App-Daten bestätigen?',
                                style: AmpColors.textStyleForeground),
                            backgroundColor: AmpColors.colorBackground,
                            actions: <Widget>[
                              ampDialogButton(
                                text: 'Abbrechen',
                                onPressed: Navigator.of(context).pop,
                              ),
                              ampDialogButton(
                                text: 'Bestätigen',
                                onPressed: () {
                                  Prefs.clear();
                                  SystemNavigator.pop();
                                },
                              ),
                            ],
                          );
                        });
                  },
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          elevation: 0,
          backgroundColor: AmpColors.colorBackground,
          splashColor: AmpColors.colorForeground,
          onPressed: () {
            dsbUpdateWidget(() {});
            Animations.changeScreenEaseOutBackReplace(
                MyApp(initialIndex: 2), context);
          },
          label: Text(
            'zurück',
            style: TextStyle(color: AmpColors.colorForeground),
          ),
          icon: Icon(
            Icons.arrow_back,
            color: AmpColors.colorForeground,
          ),
        ),
      )
    ]);
  }

  void showInputSubListItemSpacingDialog(BuildContext context) {
    final subListSpacingInputFormKey = GlobalKey<FormFieldState>();
    final subListSpacingInputFormController =
        TextEditingController(text: Prefs.subListItemSpace.toString());
    showAmpTextDialog(
      context: context,
      title: 'Listenelementabstand',
      children: (context) => [
        ampFormField(
          controller: subListSpacingInputFormController,
          key: subListSpacingInputFormKey,
          keyboardType: TextInputType.number,
          validator: Widgets.numberValidator,
        ),
      ],
      actions: (context) => ampDialogButtonsSaveAndCancel(
        onCancel: () => Navigator.of(context).pop(),
        onSave: () {
          if (!subListSpacingInputFormKey.currentState.validate()) return;
          Prefs.subListItemSpace =
              double.parse(subListSpacingInputFormController.text.trim());
          setState(() => Prefs.subListItemSpace);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void showInputTimerDialog(BuildContext context) {
    final timerInputFormKey = GlobalKey<FormFieldState>();
    final timerInputFormController =
        TextEditingController(text: Prefs.timer.toString());
    showAmpTextDialog(
      context: context,
      title: 'Timer (Minuten)',
      children: (context) => [
        ampFormField(
          controller: timerInputFormController,
          key: timerInputFormKey,
          keyboardType: TextInputType.number,
          validator: Widgets.numberValidator,
        ),
      ],
      actions: (context) => ampDialogButtonsSaveAndCancel(
        onCancel: () => Navigator.of(context).pop(),
        onSave: () {
          if (!timerInputFormKey.currentState.validate()) return;
          try {
            setState(() => Prefs.setTimer(
                int.parse(timerInputFormController.text.trim()), () => null));
          } catch (e) {
            return;
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class DevOptionsValues {
  static TabController tabController;
}