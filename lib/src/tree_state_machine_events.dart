import 'dart:async';

import 'package:flutter/material.dart';
import 'package:state_tree_router/state_tree_router.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

/// A widget for receiving notifications from a [TreeStateMachine].
///
/// The state machine providing the events is obtained using [TreeStateMachineProvider.of].
class TreeStateMachineEvents extends StatefulWidget {
  const TreeStateMachineEvents({
    Key? key,
    required this.child,
    this.transitionRootKey,
    this.onTransition,
  }) : super(key: key);

  /// The widget below this widget in the tree.
  final Widget child;

  /// Optional state key indicating a state that is used as a root for transition events.
  ///
  /// If provided, [onTransition] will be called only for transitions that occur between states that
  /// are desecendant of the transition root.
  final StateKey? transitionRootKey;

  /// Called when a state transition has occurred within the state machine.
  final void Function(Transition)? onTransition;

  @override
  State createState() => _TreeStateMachineEventsState();
}

class _TreeStateMachineEventsState extends State<TreeStateMachineEvents> {
  StreamSubscription? _transitionSubscription;

  @override
  void didUpdateWidget(TreeStateMachineEvents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTransition != oldWidget.onTransition ||
        widget.transitionRootKey != oldWidget.transitionRootKey) {
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
    if (widget.onTransition == null) {
      return;
    }

    var stateMachineContext = TreeStateMachineProvider.of(context);
    if (stateMachineContext == null) {
      return;
    }

    var currentState = stateMachineContext.currentState;
    var stateMachine = currentState.stateMachine;

    var transtitions = widget.transitionRootKey != null
        ? stateMachine.transitions.where((t) => !t.exitPath.contains(widget.transitionRootKey))
        : stateMachine.transitions;

    _transitionSubscription = transtitions.listen(widget.onTransition);
  }

  void _unsubscribe() {
    _transitionSubscription?.cancel();
  }
}
