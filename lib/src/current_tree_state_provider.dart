import 'package:flutter/material.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

class TreeStateMachineInfo {
  final CurrentState currentState;
  TreeStateMachineInfo(this.currentState);
}

class CurrentTreeStateProvider extends StatelessWidget {
  const CurrentTreeStateProvider({
    Key? key,
    required this.currentState,
    required this.child,
  }) : super(key: key);

  final CurrentState currentState;
  final Widget child;

  @override
  Widget build(BuildContext context) => _InheritedStateMachineInfo(
        currentState: currentState,
        child: child,
      );

  static TreeStateMachineInfo? of(BuildContext context) {
    var inheritedTheme = context.dependOnInheritedWidgetOfExactType<_InheritedStateMachineInfo>();
    return inheritedTheme != null ? TreeStateMachineInfo(inheritedTheme.currentState) : null;
  }
}

class _InheritedStateMachineInfo extends InheritedWidget {
  _InheritedStateMachineInfo({
    Key? key,
    required this.currentState,
    required Widget child,
  }) : super(key: key, child: child);

  final CurrentState currentState;
  late final StateKey _currentStateKey = currentState.key;

  @override
  bool updateShouldNotify(_InheritedStateMachineInfo old) {
    //var changed = _currentStateKey != old._currentStateKey;
    var changed = currentState != old.currentState;
    return changed;
  }
}
