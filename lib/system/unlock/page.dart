import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jxledger/ipc/event.dart';

import '../../app/constants.dart';
import '../../app/theme.dart';
import '../../core/mode.dart';
import '../../core/locator.dart';
import '../../ipc/client.dart';
import '../../ipc/mixins/broadcaster.dart';
import '../../ipc/server.dart';
import '../../widgets/buttons/action.dart';
import '../../widgets/context_menu.dart';
import '../../widgets/header.dart';
import 'controller.dart';

class SystemUnlockPage extends StatefulWidget {
  const SystemUnlockPage({super.key});

  @override
  State<SystemUnlockPage> createState() => _SystemUnlockPageState();
}

class _SystemUnlockPageState extends State<SystemUnlockPage> with IpcMixinsBroadcaster {
  SystemUnlockController get controller => CoreLocator.getit<SystemUnlockController>();

  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool showPassword = false;
  bool isFirstRun = CoreMode.isFirstRun;
  bool _isProcessing = false;

  String? error;

  @override
  IpcClient get ipcClient => CoreLocator.getit<IpcClient>();

  @override
  IpcServer get ipcServer => CoreLocator.getit<IpcServer>();

  @override
  void initState() {
    super.initState();
    _password.addListener(_updateState);
    _confirm.addListener(_updateState);
    controller.init();
    broadcasterListen();
  }

  @override
  void dispose() {
    _password.removeListener(_updateState);
    _confirm.removeListener(_updateState);
    _password.dispose();
    _confirm.dispose();
    broadcasterDispose();
    super.dispose();
  }

  @override
  void broadcasterAction(IpcBroadcastEvent event) {
    if (event.action != 'database_created') {
      return;
    }

    if (isFirstRun) {
      setState(() {
        isFirstRun = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(child: SizedBox(width: 300, child: isFirstRun ? _buildFirstRunUI() : _buildUnlockUI())),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('v$appVersion', style: TextStyle(fontSize: 12, color: AppTheme.textInactive)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstRunUI() {
    return WidgetsHeader(
      title: "Welcome!",
      titleFontSize: 20,
      subtitle: "Create a password for securing your vault",
      subtitleFontSize: 14,
      spacing: 16,
      centered: true,
      children: [
        TextField(
          contextMenuBuilder: (context, editableTextState) {
            return WidgetsContextMenu(
              anchor: editableTextState.contextMenuAnchors.primaryAnchor,
              buttonItems: editableTextState.contextMenuButtonItems,
            );
          },
          controller: _password,
          obscureText: !showPassword,
          readOnly: _isProcessing,
          onSubmitted: _registering,
          onChanged: _validatePassword,
          decoration: InputDecoration(
            labelText: "Password",
            enabledBorder: error == null || _isProcessing
                ? Theme.of(context).inputDecorationTheme.enabledBorder
                : Theme.of(context).inputDecorationTheme.errorBorder,
            focusedBorder: error == null || _isProcessing
                ? Theme.of(context).inputDecorationTheme.focusedBorder
                : Theme.of(context).inputDecorationTheme.errorBorder,
          ),
        ),

        TextField(
          contextMenuBuilder: (context, editableTextState) {
            return WidgetsContextMenu(
              anchor: editableTextState.contextMenuAnchors.primaryAnchor,
              buttonItems: editableTextState.contextMenuButtonItems,
            );
          },
          controller: _confirm,
          obscureText: !showPassword,
          readOnly: _isProcessing,
          onSubmitted: _registering,
          onChanged: _validatePassword,
          decoration: InputDecoration(
            labelText: "Confirm Password",
            enabledBorder: error == null || _isProcessing
                ? Theme.of(context).inputDecorationTheme.enabledBorder
                : Theme.of(context).inputDecorationTheme.errorBorder,
            focusedBorder: error == null || _isProcessing
                ? Theme.of(context).inputDecorationTheme.focusedBorder
                : Theme.of(context).inputDecorationTheme.errorBorder,
          ),
        ),

        if (error != null)
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.inputErrorText),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(value: showPassword, onChanged: (v) => setState(() => showPassword = v!)),
            Text("Show password"),
          ],
        ),

        WidgetsButtonsAction(
          label: "Create Vault",
          initialState: WidgetsButtonActionState.action,
          evaluator: _evaluatorRegister,
          onPressed: _registering,
        ),
      ],
    );
  }

  Widget _buildUnlockUI() {
    return WidgetsHeader(
      title: "Please enter password to unlock",
      titleFontSize: 16,
      spacing: 20,
      centered: true,
      children: [
        TextField(
          contextMenuBuilder: (context, editableTextState) {
            return WidgetsContextMenu(
              anchor: editableTextState.contextMenuAnchors.primaryAnchor,
              buttonItems: editableTextState.contextMenuButtonItems,
            );
          },
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          readOnly: _isProcessing,
          onSubmitted: _unlocking,
          decoration: InputDecoration(labelText: "Password", errorText: _isProcessing ? null : error),
        ),

        WidgetsButtonsAction(
          label: "Unlock",
          initialState: WidgetsButtonActionState.action,
          evaluator: _evaluatorUnlock,
          onPressed: _unlocking,
        ),
      ],
    );
  }

  void _validatePassword(dynamic value) {
    if (_password.text.isNotEmpty && _confirm.text.isNotEmpty && _password.text == _confirm.text) {
      setState(() {
        error = null;
      });
      return;
    }

    if (_password.text.isEmpty) {
      setState(() => error = "Password cannot be empty");
      return;
    }

    if (_confirm.text.isEmpty) {
      setState(() => error = "Please confirm your password");
      return;
    }

    if (_password.text != _confirm.text) {
      setState(() => error = "Password and confirmation does not match");
      return;
    }
  }

  void _evaluatorRegister(WidgetsButtonsActionState s) {
    if (_password.text.isEmpty || _confirm.text.isEmpty || _password.text != _confirm.text) {
      s.disable();
      return;
    }

    if (_isProcessing) {
      s.progress();
      return;
    }

    s.action();
  }

  void _evaluatorUnlock(WidgetsButtonsActionState s) {
    if (_password.text.isEmpty) {
      s.disable();
      return;
    }

    if (_isProcessing) {
      s.progress();
      return;
    }

    s.action();
  }

  void _registering(dynamic s) async {
    _validatePassword(null);

    if (error != null) {
      return;
    }

    setState(() {
      _isProcessing = true;
      error = null;
    });

    final ok = await controller.unlock(_password.text);

    if (!mounted) return;

    if (ok) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Router.neglect(context, () {
          context.go("/transactions");
        });
      });
    } else {
      setState(() {
        _isProcessing = false;
        error = "Failed to create vault";
      });
    }
  }

  void _unlocking(dynamic s) async {
    setState(() {
      _isProcessing = true;
      error = null;
    });

    final ok = await controller.unlock(_password.text);

    if (!mounted) return;

    if (ok) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Router.neglect(context, () {
          context.go("/transactions");
        });
      });
    } else {
      setState(() {
        _isProcessing = false;
        error = "Invalid password";
      });
    }
  }

  void _updateState() {
    setState(() {});
  }
}
