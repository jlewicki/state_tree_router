import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
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

  final Logger _log = Logger('StateTreeRouterDelegate');

  CurrentState? _currentState;
  StreamSubscription? _transitionsSubscription;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Future<void> setNewRoutePath(StateTreeRouteInfo configuration) async {
    _transitionsSubscription?.cancel();

    var stateMachine = _currentState?.stateMachine ?? TreeStateMachine(stateTreeBuilder);
    if (stateMachine.isStarted) {
      await stateMachine.stop();
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
    if (_currentState != null) {
      _log.fine('Creating pages for active states ${_currentState!.activeStates.join(',')}');
    }

    var pages = _currentState != null
        ? _createPages(stateTreeViews, _currentState!, _log)
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
    Logger logger,
  ) {
    var pages = currentState.activeStates.reversed
        .map((stateKey) => MapEntry<StateKey, WidgetBuilder?>(stateKey, treeStateViews[stateKey]))
        .where((entry) => entry.value != null)
        .map((entry) => StateTreePage(entry.key, currentState, entry.value!))
        .toList();
    if (pages.isEmpty) {
      logger.warning(
          'No pages created for ${currentState.activeStates.map((e) => "'$e'").join(', ')}');
    }
    return pages;
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
  StreamSubscription? _transitionsSubscription;
  final _log = Logger('NestedMachineRouterDelegate');

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

  void _onTransition(Transition trans) {
    if (trans.isToFinalState) {
      _transitionsSubscription?.cancel();
    } else {
      notifyListeners();
    }
  }

  List<Page> _createStateTreePages(BuildContext context) {
    var stateMachineInfo = CurrentTreeStateProvider.of(context);
    if (stateMachineInfo == null) {
      _log.warning('Unable to find current state machine in widget tree');
      return const <Page>[];
    }

    var nestedMachineData = stateMachineInfo.currentState.dataValue<NestedMachineData>(stateKey);
    if (nestedMachineData == null) {
      _log.warning('Unable to find nested machine data in widget tree');
      return const <Page>[];
    }

    var currentState = nestedMachineData.nestedState;
    if (currentState != null) {
      _transitionsSubscription?.cancel();
      _transitionsSubscription = currentState.stateMachine.transitions.listen(_onTransition);
    }

    return StateTreeRouterDelegate._createPages(stateTreeViews, currentState, _log);
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
  StreamSubscription? _transitionsSubscription;
  final _log = Logger('ChildTreeStateRouterDelegate');

  @override
  Future<void> setNewRoutePath(StateTreeRouteInfo configuration) async {
    // This is not required for an nested router delegate because it does not
    // parse route
    assert(false);
  }

  void _onTransition(Transition trans) => notifyListeners();

  @override
  Widget build(BuildContext context) {
    var currentState = CurrentTreeStateProvider.of(context)?.currentState;
    if (currentState != null) {
      _transitionsSubscription = currentState.stateMachine.transitions.listen(_onTransition);
    }

    var pages = currentState != null
        ? StateTreeRouterDelegate._createPages(stateTreeViews, currentState, _log)
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
}
