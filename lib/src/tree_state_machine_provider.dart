import 'package:flutter/material.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

/// Provides information about a [TreeStateMachine] to widgets.
class TreeStateMachineInfo {
  TreeStateMachineInfo(this.currentState);

  /// The current state of a [TreeStateMachine].
  final CurrentState currentState;
}

/// Provides a [TreeStateMachineInfo] value to descendant widgets.
class TreeStateMachineProvider extends StatelessWidget {
  const TreeStateMachineProvider({
    Key? key,
    required this.currentState,
    required this.child,
  }) : super(key: key);

  /// The current state of the state machine to be provided to descendant widgets.
  final CurrentState currentState;

  /// The widget below this widget in the tree.
  final Widget child;

  /// The data from the closest [TreeStateMachineProvider] instance that encloses the given context.
  static TreeStateMachineInfo? of(BuildContext context) {
    var inheritedInfo = context.dependOnInheritedWidgetOfExactType<_InheritedStateMachineInfo>();
    return inheritedInfo != null ? TreeStateMachineInfo(inheritedInfo.currentState) : null;
  }

  @override
  Widget build(BuildContext context) => _InheritedStateMachineInfo(
        currentState: currentState,
        child: child,
      );
}

class _InheritedStateMachineInfo extends InheritedWidget {
  const _InheritedStateMachineInfo({
    Key? key,
    required this.currentState,
    required Widget child,
  }) : super(key: key, child: child);

  final CurrentState currentState;

  @override
  bool updateShouldNotify(_InheritedStateMachineInfo old) {
    var changed = currentState != old.currentState;
    return changed;
  }
}
