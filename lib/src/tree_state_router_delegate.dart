import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import './current_tree_state_provider.dart';

// useful example of nested routers:
// https://gist.github.com/johnpryan/bbca91e23bbb4d39247fa922533be7c9

class StateTreeRouteInfo {
  final StateKey currentState;
  StateTreeRouteInfo(this.currentState);
}

class StateTreePage extends Page<void> {
  StateTreePage(this.stateKey, this.currentState, this.builder)
      : super(key: ValueKey<StateKey>(stateKey));

  final StateKey stateKey;
  final WidgetBuilder builder;
  final CurrentState currentState;

  @override
  Route createRoute(BuildContext context) {
    return MaterialPageRoute(
      settings: this,
      builder: (context) => CurrentTreeStateProvider(
        currentState: currentState,
        child: Builder(builder: builder),
      ),
    );
  }
}

class StateTreeRouteInfoParser extends RouteInformationParser<StateTreeRouteInfo> {
  StateTreeRouteInfoParser(this._rootKey);

  final StateKey _rootKey;

  @override
  Future<StateTreeRouteInfo> parseRouteInformation(RouteInformation routeInformation) {
    if (routeInformation.location == '/') {
      return SynchronousFuture(StateTreeRouteInfo(_rootKey));
    }
    throw UnimplementedError();
  }
}

class StateTreeRouterDelegate extends RouterDelegate<StateTreeRouteInfo>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  /// Creates a [StateTreeRouterDelegate].
  StateTreeRouterDelegate({
    required this.stateTreeBuilder,
    this.stateTreeViews = const <StateKey, WidgetBuilder>{},
    this.scaffoldPages = false,
  });

  final StateTreeBuilder stateTreeBuilder;

  final Map<StateKey, WidgetBuilder> stateTreeViews;

  final bool scaffoldPages;

  CurrentState? _currentState;
  StreamSubscription? _transitionsSubscription;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Future<void> setNewRoutePath(StateTreeRouteInfo configuration) async {
    var stateMachine = _currentState?.stateMachine ?? TreeStateMachine(stateTreeBuilder);
    if (stateMachine.isStarted) {
      await stateMachine.stop();
      _transitionsSubscription?.cancel();
    }
    _currentState = await stateMachine.start(configuration.currentState);
    _transitionsSubscription = stateMachine.transitions.listen(_onTransition);
  }

  void _onTransition(Transition trans) => notifyListeners();

  @override
  Widget build(BuildContext context) {
    // build may be called while before the setNewRoutePath future completes, so we display a
    // loading indicattor while that is in progress
    // TODO: add ctor prop for loading content
    var pages = _currentState != null
        ? _createPages(stateTreeViews, _currentState!)
        : [_createLoadingPage()];
    return Navigator(
      key: navigatorKey,
      pages: pages,
      onPopPage: (route, result) {
        if (!route.didPop(result)) return false;
        notifyListeners();
        return true;
      },
    );
  }

  Page _createLoadingPage() {
    return const MaterialPage(
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  static List<StateTreePage> _createPages(
    Map<StateKey, WidgetBuilder> treeStateViews,
    CurrentState currentState,
  ) {
    return currentState.activeStates.reversed
        .map((stateKey) => MapEntry<StateKey, WidgetBuilder?>(stateKey, treeStateViews[stateKey]))
        .where((entry) => entry.value != null)
        .map((entry) => StateTreePage(entry.key, currentState, entry.value!))
        .toList();
  }
}

class NestedMachineRouterDelegate extends RouterDelegate<StateTreeRouteInfo>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  NestedMachineRouterDelegate({
    required this.stateKey,
    required this.stateTreeViews,
  });

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  final StateKey stateKey;

  final Map<StateKey, WidgetBuilder> stateTreeViews;

  @override
  Future<void> setNewRoutePath(StateTreeRouteInfo configuration) async {
    // This is not required for an nested router delegate because it does not
    // parse route
    assert(false);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: _createStateTreePages(context),
      onPopPage: (route, result) {
        notifyListeners();
        return route.didPop(result);
      },
    );
  }

  List<Page> _createStateTreePages(BuildContext context) {
    var stateMachineInfo = CurrentTreeStateProvider.of(context);
    if (stateMachineInfo == null) {
      return const <Page>[];
    }

    var nestedMachineData = stateMachineInfo.currentState.dataValue<NestedMachineData>(stateKey);
    if (nestedMachineData == null) {
      return const <Page>[];
    }

    var currentState = nestedMachineData.nestedState;
    return StateTreeRouterDelegate._createPages(stateTreeViews, currentState);
  }
}

class ChildTreeStateRouterDelegate extends RouterDelegate<StateTreeRouteInfo>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  ChildTreeStateRouterDelegate({
    required this.stateTreeViews,
  });

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  final Map<StateKey, WidgetBuilder> stateTreeViews;

  @override
  Future<void> setNewRoutePath(StateTreeRouteInfo configuration) async {
    // This is not required for an nested router delegate because it does not
    // parse route
    assert(false);
  }

  @override
  Widget build(BuildContext context) {
    var currentState = CurrentTreeStateProvider.of(context)?.currentState;
    var pages = currentState != null
        ? StateTreeRouterDelegate._createPages(stateTreeViews, currentState)
        : <Page>[];
    return Navigator(
      key: navigatorKey,
      pages: pages,
      onPopPage: (route, result) {
        notifyListeners();
        return route.didPop(result);
      },
    );
  }

  List<Page> _createStateTreePages(BuildContext context) {
    var stateMachineInfo = CurrentTreeStateProvider.of(context);
    if (stateMachineInfo == null) {
      return const <Page>[];
    }

    var currentState = stateMachineInfo.currentState;
    return currentState.activeStates.reversed
        .map((stateKey) => MapEntry<StateKey, WidgetBuilder?>(stateKey, stateTreeViews[stateKey]))
        .where((entry) => entry.value != null)
        .map((entry) => StateTreePage(entry.key, currentState, entry.value!))
        .toList();
  }
}
