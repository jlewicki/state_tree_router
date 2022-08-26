import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:state_tree_router/state_tree_router.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

/// A [RouterDelegate] that receives routing information from the state transitions of a
/// [TreeStateMachine].
///
/// An application configures [StateTreeRouterDelegate] with a [stateMachine], and a list of
/// [TreeStatePage]s that indicate how individual states in the state machine should be
/// visualized.
///
/// As state transitions occur within the state machine, the router delegate will determine there is
/// a [TreeStatePage] that corresponds to the an active state of the state machine.  If a page is
/// available, it is displayed by the [Navigator] returned by [build].
class StateTreeRouterDelegate extends RouterDelegate<StateTreeRouteInfo>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  /// Creates a [StateTreeRouterDelegate].
  StateTreeRouterDelegate({
    required this.stateMachine,
    required List<TreeStatePage> pages,
    this.scaffoldPages = false,
  })  : pages = pages.toList(),
        _pageMap = _toPageMap(pages, 'stateTreePages');

  /// The list of pages that can be displayed by this router delegate.
  final List<TreeStatePage> pages;

  /// The [StateTreeBuilder] that defines the state tree providing navigation notifications to this
  /// router.
  final TreeStateMachine stateMachine;

  /// Returns 'true' if the content of page should be wrapped in a [Scaffold] widget.
  ///
  /// This is intended as a convenience to page developers, so that each page does not have to be
  /// scaffolded individually.
  final bool scaffoldPages;

  /// The key used for retrieving the current navigator.
  @override
  final navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'StateTreeRouterDelegate');

  final Map<StateKey, TreeStatePage> _pageMap;
  final Logger _log = Logger('StateTreeRouterDelegate');
  CurrentState? _currentState;

  @override
  Future<void> setNewRoutePath(StateTreeRouteInfo configuration) async {
    if (stateMachine.isStarted) {
      await stateMachine.stop();
    }
    _currentState = await stateMachine.start(configuration.currentState);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentState != null) {
      _log.fine('Creating pages for active states ${_currentState!.activeStates.join(',')}');
    }

    // build may be called before the setNewRoutePath future completes, so we display a loading
    // indicator while that is in progress
    var pages = _currentState != null
        ? _createPages(_pageMap, _currentState!, _log)
            .map((page) => scaffoldPages ? _scaffoldPage(page) : page)
            .toList()
        : [_createLoadingPage()];

    if (pages.isEmpty) {
      _log.warning(
          'No pages available to display active states ${_currentState!.activeStates.join(',')}');
      pages = [_createEmptyPagesPage(_currentState!.activeStates)];
    }

    var navigator = Navigator(
      key: navigatorKey,
      transitionDelegate: _TreeStateRouteTransitionDelegate(),
      pages: pages,
      onPopPage: (route, result) {
        _log.finer('Popping page for state ${(route.settings as TreeStatePage).stateKey}');
        if (!route.didPop(result)) return false;
        notifyListeners();
        return true;
      },
    );

    return _currentState != null
        ? TreeStateMachineProvider(
            currentState: _currentState!,
            child: TreeStateMachineEvents(
              onTransition: _onTransition,
              child: navigator,
            ),
          )
        : navigator;
  }

  void _onTransition(Transition transition) {
    notifyListeners();
  }

  Page _scaffoldPage(TreeStatePage page) {
    return MaterialPage(
      key: page.key,
      child: Scaffold(body: page.child),
    );
  }

  Page _createLoadingPage() {
    return const MaterialPage(
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Page _createEmptyPagesPage(List<StateKey> activeStates) {
    Widget content = Container();
    assert(() {
      content = ErrorWidget.withDetails(
          message: 'No tree state pages are available to display any of the active states: '
              '${activeStates.map((s) => '"$s"').join(', ')}.\n\n'
              'Make sure to add a page that can display one of the states to the '
              'StateTreeRouterDelegate. ');
      return true;
    }());
    return MaterialPage(
      child: Center(
        child: content,
      ),
    );
  }

  /// Creates the stack of pages that should display the current state of the state tree.
  ///
  /// Currently this returns a collection of 0 or 1 pages, but once a history feature is added to
  /// tree_state_machine, this will return a history stack which can be popped by the navigator.
  static Iterable<TreeStatePage> _createPages(
    Map<StateKey, TreeStatePage> pages,
    CurrentState currentState,
    Logger logger,
  ) {
    /// Return the deepest page that maps to an active state. By deepest, we mean the page that
    /// maps to a state as far as possible from the root state. This gives the current leaf state
    /// priority in determining the page to display, followed by its parent state, etc.
    var activePage = currentState.activeStates.reversed
        .map((stateKey) => MapEntry<StateKey, TreeStatePage?>(stateKey, pages[stateKey]))
        .where((entry) => entry.value != null)
        .map((entry) => entry.value!)
        .firstOrNull;

    if (activePage == null) {
      logger.warning(
          'No pages created for ${currentState.activeStates.map((e) => "'$e'").join(', ')}');
    }

    return activePage != null ? [activePage] : [];
  }

  static Map<StateKey, TreeStatePage> _toPageMap(
    List<TreeStatePage> pages,
    String paramName,
  ) {
    var map = <StateKey, TreeStatePage>{};
    for (var page in pages) {
      if (map.containsKey(page.stateKey)) {
        throw ArgumentError('Duplicate pages defined for state ${page.stateKey}', paramName);
      }
      map[page.stateKey] = page;
    }
    return map;
  }
}

/// A [RouterDelegate] that receives routing information from the state transitions of the
/// nested [TreeStateMachine] in a machine tree state.
///
/// This router delegate is intended for use with nested routing, providing visualization for the
/// states of [TreeStateMachine] nested within a state of an outer [TreeStateMachine].
/// Top level navigation based on the outer state machine should use [StateTreeRouterDelegate].
///
/// An application configures [NestedStateTreeRouterDelegate] with a list of [TreeStatePage]s that
/// indicate how individual states of the nested state machine should be visualized.
///
/// As state transitions occur within the state machine, the router delegate will determine there is
/// a [TreeStatePage] that corresponds to the an active state of the state machine.  If a page is
/// available, it is displayed by the [Navigator] returned by [build].
class NestedStateTreeRouterDelegate extends RouterDelegate<StateTreeRouteInfo>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  NestedStateTreeRouterDelegate({
    required List<TreeStatePage> pages,
  })  : pages = pages.toList(),
        _pageMap = StateTreeRouterDelegate._toPageMap(
          pages,
          'nestedStateTreePages',
        );

  /// The list of pages that can be displayed by this router delegate.
  final List<TreeStatePage> pages;

  /// The key used for retrieving the current navigator.
  @override
  final navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'NestedStateTreeRouterDelegate');

  final Map<StateKey, TreeStatePage> _pageMap;

  final _log = Logger('tree_state_router.NestedMachineRouterDelegate');

  @override
  Future<void> setNewRoutePath(StateTreeRouteInfo configuration) async {
    // This is not required for an nested router delegate because it does not
    // parse route
    assert(false);
  }

  @override
  Widget build(BuildContext context) {
    var stateMachineInfo = TreeStateMachineProvider.of(context);
    if (stateMachineInfo == null) {
      var message = 'Unable to find tree state machine in widget tree';
      _log.warning(message);
      return ErrorWidget.withDetails(message: message);
    }

    var currentState = stateMachineInfo.currentState;
    var nestedMachineData = currentState.dataValue<NestedMachineData>();
    if (nestedMachineData == null) {
      // This can happen when the nested state machine reaches a final state. In this case this
      // router is notified of the transition to
      var message = 'Unable to find nested machine data in active states '
          '${currentState.activeStates.map((e) => '"${e.toString()}"').join(', ')}. '
          'An empty Container will be displated.';
      _log.warning(message);
      return ErrorWidget.withDetails(message: message);
    }

    return TreeStateMachineProvider(
      currentState: nestedMachineData.nestedState,
      child: TreeStateMachineEvents(
        onTransition: _onTransition,
        child: Navigator(
          key: navigatorKey,
          transitionDelegate: _TreeStateRouteTransitionDelegate(),
          pages: _createStateTreePages(context, nestedMachineData.nestedState),
          onPopPage: (route, result) {
            _log.finer('Popping page for state ${(route.settings as TreeStatePage).stateKey}');
            if (!route.didPop(result)) return false;
            notifyListeners();
            return route.didPop(result);
          },
        ),
      ),
    );
  }

  void _onTransition(Transition trans) {
    // Do not notify when the nested state machine reaches a final state. If we were to notify, then
    // we would schedule a call to build for this router.  However, the parent machine tree state
    // that owns the nested state machine transition to a different state when the final state is
    // reached, which means that when the scheduled build actually runs,
    // currentState.dataValue<NestedMachineData>() will no longer find a nested state machine, and
    // the build method will fail.
    if (!trans.isToFinalState) {
      notifyListeners();
    }
  }

  List<TreeStatePage> _createStateTreePages(BuildContext context, CurrentState nestedCurrentState) {
    return StateTreeRouterDelegate._createPages(_pageMap, nestedCurrentState, _log).toList();
  }
}

class ChildTreeStateRouterDelegate extends RouterDelegate<StateTreeRouteInfo>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  ChildTreeStateRouterDelegate({
    required List<TreeStatePage> pages,
  }) : _treeStatePages = StateTreeRouterDelegate._toPageMap(
          pages,
          'nestedStateTreePages',
        );

  @override
  final navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'ChildTreeStateRouterDelegate');
  final Map<StateKey, TreeStatePage> _treeStatePages;
  final _log = Logger('ChildTreeStateRouterDelegate');

  @override
  Future<void> setNewRoutePath(StateTreeRouteInfo configuration) async {
    // This is not required for an nested router delegate because it does not
    // parse routes
    assert(false);
  }

  void _onTransition(Transition trans) => notifyListeners();

  @override
  Widget build(BuildContext context) {
    var currentState = TreeStateMachineProvider.of(context)?.currentState;

    var pages = currentState != null
        ? StateTreeRouterDelegate._createPages(_treeStatePages, currentState, _log).toList()
        : <TreeStatePage>[];

    return TreeStateMachineEvents(
      onTransition: _onTransition,
      child: Navigator(
        key: navigatorKey,
        transitionDelegate: _TreeStateRouteTransitionDelegate(),
        pages: pages,
        onPopPage: (route, result) {
          _log.finer('Popping page for state ${(route.settings as TreeStatePage).stateKey}');
          if (!route.didPop(result)) return false;
          notifyListeners();
          return route.didPop(result);
        },
      ),
    );
  }
}

/// A page that can display the tree state identified by [stateKey].
class TreeStatePage extends MaterialPage<void> {
  TreeStatePage._(this.stateKey, this.builder)
      : super(key: ValueKey(stateKey), child: Builder(builder: builder));

  /// The state key identifying the tree state that is displayed by this page.
  final StateKey stateKey;

  /// The builder that creates the widget that displays the tree state.
  final WidgetBuilder builder;

  // @override
  // Route<void> createRoute(BuildContext context) {
  //   return PageRouteBuilder(
  //       settings: this,
  //       pageBuilder: (bc, _, __) => builder(bc),
  //       transitionDuration: const Duration(seconds: 0),
  //       reverseTransitionDuration: const Duration(seconds: 0));
  // }

  /// Creates a [TreeStatePage] that displays the tree state identified by [stateKey] using the
  /// provided [buillder] function.
  factory TreeStatePage.forState(
    StateKey stateKey,
    Widget Function(BuildContext, CurrentState) builder,
  ) {
    return TreeStatePage._(
      stateKey,
      (_) => TreeStateBuilder(
        key: ValueKey(stateKey),
        stateKey: stateKey,
        builder: builder,
      ),
    );
  }

  /// Creates a [TreeStatePage] that displays the data tree state, with state data of type [D] and
  /// identified by [stateKey], using the provided [buillder] function.
  static TreeStatePage forDataState<D>(
    StateKey stateKey,
    Widget Function(BuildContext, D, CurrentState) build,
  ) {
    return TreeStatePage._(
      stateKey,
      (buildContext) => DataTreeStateBuilder<D>(
        key: ValueKey(stateKey),
        stateKey: stateKey,
        builder: build,
      ),
    );
  }

  static TreeStatePage forDataState2<D, DAnc>(
    StateKey stateKey,
    Widget Function(BuildContext, D, DAnc, CurrentState) build,
  ) {
    return TreeStatePage._(
      stateKey,
      (buildContext) => DataTreeStateBuilder2<D, DAnc>(
        key: ValueKey(stateKey),
        stateKey: stateKey,
        builder: build,
      ),
    );
  }
}

class StateTreeRouteInfo {
  final StateKey currentState;
  StateTreeRouteInfo(this.currentState);
}

class StateTreeRouteInfoParser extends RouteInformationParser<StateTreeRouteInfo> {
  StateTreeRouteInfoParser(this._rootKey);

  final StateKey _rootKey;

  @override
  Future<StateTreeRouteInfo> parseRouteInformation(RouteInformation routeInformation) {
    if (routeInformation.location == '/') {
      return SynchronousFuture(StateTreeRouteInfo(_rootKey));
    }

    throw UnimplementedError('Route parsing is not yet supported.');
  }
}

// Used for degbugging purposes.
class _TreeStateRouteTransitionDelegate<T> extends DefaultTransitionDelegate<T> {
  @override
  Iterable<RouteTransitionRecord> resolve({
    required List<RouteTransitionRecord> newPageRouteHistory,
    required Map<RouteTransitionRecord?, RouteTransitionRecord> locationToExitingPageRoute,
    required Map<RouteTransitionRecord?, List<RouteTransitionRecord>> pageRouteToPagelessRoutes,
  }) {
    var records = super.resolve(
      newPageRouteHistory: newPageRouteHistory,
      locationToExitingPageRoute: locationToExitingPageRoute,
      pageRouteToPagelessRoutes: pageRouteToPagelessRoutes,
    );
    return records;
  }
}
