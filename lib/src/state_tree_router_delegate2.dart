import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_router/src/tree_state_builders.dart';
import 'package:tree_state_router/tree_state_router.dart';

class StateTreeRouteInfo {
  final StateKey currentState;
  StateTreeRouteInfo(this.currentState);
}

class _TreeStatePage extends Page<void> {
  _TreeStatePage(this.stateKey, this.currentState, this.builder)
      : super(key: ValueKey<StateKey>(stateKey));

  final StateKey stateKey;
  final WidgetBuilder builder;
  final CurrentState currentState;

  @override
  Route createRoute(BuildContext context) {
    return _TreeStatePageRoute(settings: this, builder: builder);
  }
}

class _TreeStatePageRoute extends MaterialPageRoute {
  _TreeStatePageRoute({super.settings, required super.builder});
  @override
  Widget buildContent(BuildContext context) {
    return super.buildContent(context);
  }
}

class TreeStatePage {
  TreeStatePage._(this._stateKey, this._builder);

  final StateKey _stateKey;
  final WidgetBuilder Function(CurrentState) _builder;

  _TreeStatePage _createPage(CurrentState currentState) {
    return _TreeStatePage(_stateKey, currentState, _builder(currentState));
  }

  static TreeStatePage forState(
    StateKey stateKey,
    Widget Function(BuildContext, CurrentState) builder,
  ) {
    return forDataState<void>(stateKey, (bc, _, cs) => builder(bc, cs));
  }

  static TreeStatePage forDataState<D>(
    StateKey stateKey,
    Widget Function(BuildContext, D currentData, CurrentState) builder,
  ) {
    return TreeStatePage._(stateKey, (currentState) {
      return (buildContext) {
        return CurrentTreeStateProvider(
            currentState: currentState,
            child: Builder(
              builder: (b) => TreeStateBuilder<D>(
                stateKey: stateKey,
                builder: builder,
              ),
            ));
      };
    });
  }

  static TreeStatePage forDataState2<D, DAnc>(
    StateKey stateKey,
    Widget Function(BuildContext, D currentData, DAnc ancData, CurrentState) builder, {
    CurrentDescendantChanged? onCurrentDescendantChanged,
  }) {
    return TreeStatePage._(stateKey, (currentState) {
      return (buildContext) {
        return CurrentTreeStateProvider(
            currentState: currentState,
            child: Builder(
              builder: (b) => TreeStateViewBuilder2<D, DAnc>(
                stateKey: stateKey,
                builder: builder,
                onCurrentDescendantChanged: onCurrentDescendantChanged,
              ),
            ));
      };
    });
  }
}

extension StateKeyExtensions on StateKey {
  TreeStatePage withPage(Widget Function(BuildContext, CurrentState) builder) {
    return TreeStatePage.forDataState<void>(this, (b, _, cs) => builder(b, cs));
  }

  TreeStatePage withDataPage<D>(
    Widget Function(BuildContext, D currentData, CurrentState) builder, {
    CurrentDescendantChanged? onCurrentDescendantChanged,
  }) {
    return TreeStatePage.forDataState<D>(this, builder);
  }

  TreeStatePage withDataPage2<D, DAnc>(
    Widget Function(BuildContext, D currentData, DAnc ancData, CurrentState) builder, {
    CurrentDescendantChanged? onCurrentDescendantChanged,
  }) {
    return TreeStatePage.forDataState2(this, builder,
        onCurrentDescendantChanged: onCurrentDescendantChanged);
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

/// A [RouterDelegate] that receives routing information from the state transitions of a
/// [TreeStateMachine].
///
/// An application configures [StateTreeRouterDelegate2]
class StateTreeRouterDelegate2 extends RouterDelegate<StateTreeRouteInfo>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  /// Creates a [StateTreeRouterDelegate2].
  StateTreeRouterDelegate2({
    required this.stateTreeBuilder,
    List<TreeStatePage> stateTreePages = const <TreeStatePage>[],
    this.scaffoldPages = false,
  }) : _stateTreeViews = _toPageMap(stateTreePages, 'stateTreePages');

  final StateTreeBuilder stateTreeBuilder;
  final bool scaffoldPages;
  final Map<StateKey, TreeStatePage> _stateTreeViews;
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

    List<Page> pages = _currentState != null
        ? _createPages(_stateTreeViews, _currentState!, _log)
            .map((page) => scaffoldPages ? _scaffold(page) : page)
            .toList()
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

  _TreeStatePage _scaffold(_TreeStatePage page) => _TreeStatePage(
        page.stateKey,
        _currentState!,
        (context) => Scaffold(body: page.builder(context)),
      );

  static Iterable<_TreeStatePage> _createPages(
    Map<StateKey, TreeStatePage> stateViews,
    CurrentState currentState,
    Logger logger,
  ) {
    var routerPages = currentState.activeStates.reversed
        .map((stateKey) => MapEntry<StateKey, TreeStatePage?>(stateKey, stateViews[stateKey]))
        .where((entry) => entry.value != null)
        .map((entry) => entry.value!._createPage(currentState));

    if (stateViews.isEmpty) {
      logger.warning(
          'No pages created for ${currentState.activeStates.map((e) => "'$e'").join(', ')}');
    }

    return routerPages;
  }

  static Map<StateKey, TreeStatePage> _toPageMap(List<TreeStatePage> pages, String paramName) {
    var map = <StateKey, TreeStatePage>{};
    for (var page in pages) {
      if (map.containsKey(page._stateKey)) {
        throw ArgumentError('Duplicate pages defined for state ${page._stateKey}', paramName);
      }
      map[page._stateKey] = page;
    }
    return map;
  }
}

class NestedMachineRouterDelegate2 extends RouterDelegate<StateTreeRouteInfo>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin {
  NestedMachineRouterDelegate2({
    required this.stateKey,
    required List<TreeStatePage> nestedStateTreePages,
  }) : _stateTreeViews = StateTreeRouterDelegate2._toPageMap(
          nestedStateTreePages,
          'nestedStateTreePages',
        );

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  final StateKey stateKey;
  final Map<StateKey, TreeStatePage> _stateTreeViews;
  final _log = Logger('NestedMachineRouterDelegate');
  StreamSubscription? _transitionsSubscription;

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

  List<_TreeStatePage> _createStateTreePages(BuildContext context) {
    var stateMachineInfo = CurrentTreeStateProvider.of(context);
    if (stateMachineInfo == null) {
      _log.warning('Unable to find current state machine in widget tree');
      return const <_TreeStatePage>[];
    }

    var nestedMachineData = stateMachineInfo.currentState.dataValue<NestedMachineData>(stateKey);
    if (nestedMachineData == null) {
      _log.warning('Unable to find nested machine data in widget tree');
      return const <_TreeStatePage>[];
    }

    var currentState = nestedMachineData.nestedState;
    _transitionsSubscription?.cancel();
    _transitionsSubscription = currentState.stateMachine.transitions.listen(_onTransition);

    return StateTreeRouterDelegate2._createPages(_stateTreeViews, currentState, _log).toList();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
  }
}
