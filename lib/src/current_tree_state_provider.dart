import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_router/tree_state_router.dart';

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
    var inheritedInfo = context.dependOnInheritedWidgetOfExactType<_InheritedStateMachineInfo>();
    return inheritedInfo != null ? TreeStateMachineInfo(inheritedInfo.currentState) : null;
  }
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
    //var changed = _currentStateKey != old._currentStateKey;
    var changed = currentState != old.currentState;
    return changed;
  }
}

class TreeStateEvents extends StatefulWidget {
  const TreeStateEvents({
    Key? key,
    required this.child,
    required this.stateKey,
    this.onCurrentDescendantChanged,
  }) : super(key: key);

  final Widget child;
  final StateKey stateKey;
  final CurrentDescendantChanged? onCurrentDescendantChanged;

  @override
  State<TreeStateEvents> createState() => TreeStateEventsState();
}

class TreeStateEventsState extends State<TreeStateEvents> {
  StreamSubscription? _activeDescendantSubscription;

  @override
  void didUpdateWidget(TreeStateEvents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onCurrentDescendantChanged != oldWidget.onCurrentDescendantChanged) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unsubscribe();
    _subscribe();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _subscribe() {
    if (widget.onCurrentDescendantChanged == null) {
      return;
    }

    var stateMachineContext = CurrentTreeStateProvider.of(context);
    assert(stateMachineContext != null);

    var currentState = stateMachineContext!.currentState;
    if (!currentState.isInState(widget.stateKey)) {
      return;
    }

    var stateMachine = currentState.stateMachine;
    var currentDescendantStream = stateMachine.transitions
        .where((t) => !t.exitPath.contains(widget.stateKey))
        .map((t) => t.to);

    _activeDescendantSubscription = currentDescendantStream.listen(
      (descendantKey) => widget.onCurrentDescendantChanged!(descendantKey, currentState),
    );
  }

  void _unsubscribe() {
    _activeDescendantSubscription?.cancel();
  }
}
