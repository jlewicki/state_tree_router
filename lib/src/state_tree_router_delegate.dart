import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:state_tree_router/state_tree_router.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

abstract class _BaseTreeStateRouterDelegate extends RouterDelegate<StateTreeRouteInfo>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  _BaseTreeStateRouterDelegate({
    required Logger logger,
    required this.pages,
    this.displayStateMachineErrors = false,
  })  : _log = logger,
        _pageMap = _toPageMap(pages);

  /// The list of pages that can be displayed by this router delegate.
  final List<TreeStatePage> pages;

  /// If `true`, this router delegate will display an [ErrorWidget] when the
  /// [TreeStateMachine.failedMessages] stream emits an event.
  ///
  /// This is primarily useful for debugging purposes.
  final bool displayStateMachineErrors;

  final Logger _log;
  final Map<StateKey, TreeStatePage> _pageMap;

  Widget _buildNavigatorWidget(
    List<Page> pages,
    CurrentState? currentState, {
    required bool provideCurrentState,
  }) {
    Widget widget = Navigator(
      key: navigatorKey,
      transitionDelegate: _TreeStateRouteTransitionDelegate(),
      pages: pages,
      onPopPage: _onPopPage,
    );

    if (currentState != null) {
      widget = TreeStateMachineEvents(
        onTransition: _onTransition,
        child: displayStateMachineErrors
            ? TreeStateMachineErrorDisplay(
                child: widget,
                errorBuilder: _buildErrorWidget,
              )
            : widget,
      );
    }

    if (provideCurrentState) {
      widget = TreeStateMachineProvider(currentState: currentState!, child: widget);
    }

    return widget;
  }

  /// Creates the stack of pages that should display the current state of the state tree.
  ///
  /// Currently this returns a collection of 0 or 1 pages, but once a history feature is added to
  /// tree_state_machine, this will return a history stack which can be popped by the navigator.
  @protected
  Iterable<TreeStatePage> _createPagesForActiveStates(CurrentState currentState) {
    /// Return the deepest page that maps to an active state. By deepest, we mean the page that
    /// maps to a state as far as possible from the root state. This gives the current leaf state
    /// priority in determining the page to display, followed by its parent state, etc.
    var activePage = currentState.activeStates.reversed
        .map((stateKey) => MapEntry<StateKey, TreeStatePage?>(stateKey, _pageMap[stateKey]))
        .where((entry) => entry.value != null)
        .map((entry) => entry.value!)
        .firstOrNull;

    return activePage != null ? [activePage] : [];
  }

  @protected
  Widget _buildErrorWidget(
    BuildContext buildContext,
    FailedMessage error,
    CurrentState currentState,
  ) {
    var msg = 'The state machine failed to process a message.\n\n'
        'Message: ${error.message.toString()}\n'
        'Receiving tree state: ${error.receivingState}\n\n'
        '${error.error.toString()}';
    return ErrorWidget.withDetails(message: msg);
  }

  @protected
  void _onTransition(CurrentState currentState, Transition transition) {
    notifyListeners();
  }

  @protected
  bool _onPopPage(Route<dynamic> route, dynamic result) {
    _log.finer('Popping page for state ${(route.settings as TreeStatePage).stateKey}');
    if (!route.didPop(result)) return false;
    notifyListeners();
    return true;
  }

  Page _createEmptyPagesPage(List<StateKey> activeStates, String routerName) {
    Widget content = Container();
    assert(() {
      content = ErrorWidget.withDetails(
          message: 'No tree state pages are available to display any of the active states: '
              '${activeStates.map((s) => '"$s"').join(', ')}.\n\n'
              'Make sure to add a page that can display one of the states to the $routerName.');
      return true;
    }());

    return MaterialPage(
      child: Center(
        child: content,
      ),
    );
  }

  static Map<StateKey, TreeStatePage> _toPageMap(List<TreeStatePage> pages) {
    var map = <StateKey, TreeStatePage>{};
    for (var page in pages) {
      if (map.containsKey(page.stateKey)) {
        throw ArgumentError('Duplicate pages defined for state ${page.stateKey}', 'pages');
      }
      map[page.stateKey] = page;
    }
    return map;
  }
}

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
class StateTreeRouterDelegate extends _BaseTreeStateRouterDelegate {
  StateTreeRouterDelegate({
    required this.stateMachine,
    required List<TreeStatePage> pages,
    this.scaffoldPages = false,
    bool displayStateMachineErrors = false,
  }) : super(
          logger: Logger('StateTreeRouterDelegate'),
          pages: pages,
          displayStateMachineErrors: displayStateMachineErrors,
        );

  /// The [StateTreeBuilder] that defines the state tree providing navigation notifications to this
  /// router.
  final TreeStateMachine stateMachine;

  /// Returns 'true' if the content of page should be wrapped in a [Scaffold] widget.
  ///
  /// This is intended as a convenience to page developers, so that each page does not have to be
  /// scaffolded individually.
  final bool scaffoldPages;

  CurrentState? _currentState;

  /// The key used for retrieving the current navigator.
  @override
  final navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'StateTreeRouterDelegate');

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
        ? _createPagesForActiveStates(_currentState!)
            .map((page) => scaffoldPages ? _scaffoldPage(page) : page)
            .toList()
        : [_createLoadingPage()];

    if (pages.isEmpty) {
      _log.warning(
          'No pages available to display active states ${_currentState!.activeStates.join(',')}');
      pages = [_createEmptyPagesPage(_currentState!.activeStates, 'StateTreeRouterDelegate')];
    }

    return _buildNavigatorWidget(pages, _currentState, provideCurrentState: _currentState != null);
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
}

/// A [RouterDelegate] that receives routing information from the state transitions of a
/// [TreeStateMachine] inherited from a parent [StateTreeRouterDelegate].
///
/// An application configures [StateTreeRouterDelegate] that indicate how individual states in
/// the state machine should be visualized. This router does not need to be with a state machine
/// instance. because this router delegate is intended to be nested within an outer router configured
/// with a [StateTreeRouterDelegate]. This router will share the same state machine instance with
/// the outer [StateTreeRouterDelegate].
///
/// As state transitions occur within the parent state machine, this router delegate will determine
/// if there is a [TreeStatePage] that corresponds to the an active state of the state machine. If a
/// page is available, it is displayed by the [Navigator] returned by [build].
class ChildTreeStateRouterDelegate extends _BaseTreeStateRouterDelegate {
  ChildTreeStateRouterDelegate({
    required List<TreeStatePage> pages,
    bool displayStateMachineErrors = false,
    this.supportsFinalPage = true,
  }) : super(
          logger: Logger('StateTreeRouterDelegate'),
          pages: pages,
          displayStateMachineErrors: displayStateMachineErrors,
        );

  /// If `true` (the default), an error page will be displayed if the state machine reaches a final
  /// state, and there is no page in the pages list that can display that state.
  final bool supportsFinalPage;

  /// The key used for retrieving the current navigator.
  @override
  final navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'ChildTreeStateRouterDelegate');

  @override
  Future<void> setNewRoutePath(StateTreeRouteInfo configuration) {
    throw UnsupportedError('Setting route paths is not currently supported');
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
    var activeStates = currentState.activeStates;
    var pages = _createPagesForActiveStates(currentState).cast<Page>().toList();
    if (pages.isEmpty) {
      if (currentState.stateMachine.isDone && !supportsFinalPage) {
        // If the current state machine is running as a nested machine, then there is likely a
        // Router with a NestedStateTreeRouterDelegate higher in the widget tree, which will render
        // a different page when the nested state machine finishes. In this case, a developer will
        // probably not add a page for the final state to this router delegate (since after all it
        // will never be displayed), so to avoid emitting warnings just use a transient page with
        // no visible content.
        pages = [MaterialPage(child: Container())];
      } else {
        _log.warning(
          'No pages available to display active states ${currentState.activeStates.join(',')}',
        );
        pages = [_createEmptyPagesPage(activeStates, 'ChildTreeStateRouterDelegate')];
      }
    }

    return _buildNavigatorWidget(pages, currentState, provideCurrentState: false);
  }

  @override
  void _onTransition(CurrentState currentState, Transition transition) {
    if (!transition.isToFinalState || supportsFinalPage) {
      notifyListeners();
    }
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
class NestedStateTreeRouterDelegate extends _BaseTreeStateRouterDelegate {
  NestedStateTreeRouterDelegate({
    required List<TreeStatePage> pages,
    bool displayStateMachineErrors = false,
  }) : super(
          logger: Logger('StateTreeRouterDelegate'),
          pages: pages,
          displayStateMachineErrors: displayStateMachineErrors,
        );

  /// The key used for retrieving the current navigator.
  @override
  final navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'NestedStateTreeRouterDelegate');

  @override
  Future<void> setNewRoutePath(StateTreeRouteInfo configuration) {
    throw UnsupportedError('Setting route paths is not currently supported');
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

    var pages = _createPagesForActiveStates(nestedMachineData.nestedCurrentState).toList();
    return _buildNavigatorWidget(pages, nestedMachineData.nestedCurrentState,
        provideCurrentState: true);
  }

  @override
  void _onTransition(CurrentState currentState, Transition transition) {
    // Do not notify when the nested state machine reaches a final state. If we were to notify, then
    // we would schedule a call to build for this router.  However, the parent machine tree state
    // that owns the nested state machine transition to a different state when the final state is
    // reached, which means that when the scheduled build actually runs,
    // currentState.dataValue<NestedMachineData>() will no longer find a nested state machine, and
    // the build method will fail.
    if (!transition.isToFinalState) {
      notifyListeners();
    }
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

  /// Creates a [TreeStatePage] that displays the tree state, identified by [stateKey], using the
  /// provided [buillder] function.
  ///
  ///
  static TreeStatePage forDataState<D>(
    StateKey stateKey,
    Widget Function(BuildContext, D, CurrentState) build, {
    StateKey? dataStateKey,
  }) {
    return TreeStatePage._(
      stateKey,
      (buildContext) => DataTreeStateBuilder<D>(
        key: ValueKey(stateKey),
        stateKey: stateKey,
        dataStateKey: dataStateKey,
        builder: build,
      ),
    );
  }

  static TreeStatePage forDataState2<D, DAnc>(
    StateKey stateKey,
    Widget Function(BuildContext, D, DAnc, CurrentState) build, {
    StateKey? dataStateKey1,
    StateKey? dataStateKey2,
  }) {
    return TreeStatePage._(
      stateKey,
      (buildContext) => DataTreeStateBuilder2<D, DAnc>(
        key: ValueKey(stateKey),
        stateKey: stateKey,
        dataStateKey1: dataStateKey1,
        dataStateKey2: dataStateKey2,
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
