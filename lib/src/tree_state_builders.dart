import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:state_tree_router/src/tree_state_machine_provider.dart';
import 'package:tree_state_machine/async.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

typedef _TreeStateDataListWidgetBuilder = Widget Function(
  BuildContext context,
  List stateDataList,
  CurrentState currentState,
);

/// A function that constructs widget that visualizes an active tree state in a state machine.
///
/// The function is provided the [currentState] of the tree state machine.
typedef TreeStateWidgetBuilder = Widget Function(
  BuildContext context,
  CurrentState currentState,
);

/// A function that constructs widget that visualizes a tree state, using data type of [D] from
/// an active data tree state.
///
/// The function is provided the current [stateData] for the state, and the [currentState] of the
/// tree state machine.
typedef DataTreeStateWidgetBuilder<D> = Widget Function(
  BuildContext context,
  D stateData,
  CurrentState currentState,
);

/// A function that constructs widget that visualizes a tree state, using data types of [D1] and
/// [D2] from active data tree states.
///
/// The function is provided the current [stateData1] and [stateData2] for the data states, along
/// with the [currentState] of the tree state machine.
typedef DataTreeStateWidgetBuilder2<D1, D2> = Widget Function(
  BuildContext context,
  D1 stateData1,
  D2 stateData2,
  CurrentState currentState,
);

/// A function that constructs widget that visualizes a tree state, using data types of [D1], [D2],
/// and [D3] from active data tree states.
///
/// The function is provided the current [stateData1], [stateData2], and [stateData3] for the data
/// states, along with the [currentState] of the tree state machine.
typedef DataTreeStateWidgetBuilder3<D1, D2, D3> = Widget Function(
  BuildContext context,
  D1 stateData1,
  D2 stateData2,
  D3 stateData3,
  CurrentState currentState,
);

/// A widget that builds itself when a specific tree state is an active state in a [TreeStateMachine].
///
/// This widget obtains a state machine using [TreeStateMachineProvider.of], and therefore it is a
/// requirement that a [TreeStateMachineProvider] is above this widget in the widget tree.
///
/// The tree state for which this widget builds itself is identified by [stateKey]. If this state
/// is an active state in the state machine, the [builder] function is called to obtain the widget
/// to display.
class TreeStateBuilder extends StatelessWidget {
  const TreeStateBuilder({
    Key? key,
    required this.stateKey,
    required this.builder,
  }) : super(key: key);

  /// The state key of the tree state that is built by this builder.
  final StateKey stateKey;

  /// The function that produces the widget that visualizes the tree state.
  final TreeStateWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    var stateMachineInfo = TreeStateMachineProvider.of(context);
    if (stateMachineInfo == null) {
      return ErrorWidget.withDetails(
        message: 'Unable to build widget for tree state "$stateKey", '
            'because a state machine was not found in the widget tree.',
      );
    }

    if (!stateMachineInfo.currentState.isInState(stateKey)) {
      Widget widget = Container();
      assert(() {
        widget = ErrorWidget.withDetails(
          message: 'Unable to build widget for tree state "$stateKey", '
              'because "$stateKey" is not an active state in the state machine.',
        );
        return true;
      }());
      return widget;
    }

    return builder(context, stateMachineInfo.currentState);
  }
}

abstract class _BaseDataTreeStateBuilder extends StatefulWidget {
  const _BaseDataTreeStateBuilder(
    Key? key,
    this.stateKey,
    this.stateDataResolvers,
    this._widgetBuilder,
  ) : super(key: key);

  final StateKey stateKey;
  final List<StateDataResolver> stateDataResolvers;
  final _TreeStateDataListWidgetBuilder _widgetBuilder;

  @override
  _TreeStateBuilderState createState() => _TreeStateBuilderState();
}

/// A widget that builds itself, using tree state data, itself when a specific tree state is an
/// active state in a [TreeStateMachine].
///
/// The tree state for which this widget builds itself is identified by [stateKey]. If this state
/// is an active state in the state machine, the [builder] function is called to obtain the widget
/// to display.
///
/// The type parameter [D] indicates the type of state data that is provided to the [builder]
/// function. This data is obtained from an active data state, which may be the state identified by
/// [stateKey], or one of its ancestor data states.
class DataTreeStateBuilder<D> extends _BaseDataTreeStateBuilder {
  DataTreeStateBuilder({
    Key? key,
    required StateKey stateKey,
    required DataTreeStateWidgetBuilder<D> builder,
    StateKey? dataStateKey,
  }) : super(
            key,
            stateKey,
            [StateDataResolver<D>(dataStateKey)],
            (context, dataList, currentState) => builder(
                  context,
                  dataList.getAs<D>(0),
                  currentState,
                ));
}

/// A widget that builds itself, using tree state data, itself when a specific tree state is an
/// active state in a [TreeStateMachine].
///
/// The tree state for which this widget builds itself is identified by [stateKey]. If this state
/// is an active state in the state machine, the [builder] function is called to obtain the widget
/// to display.
///
/// The type parameters [D1] and [D2] indicate the types of state data that is provided to the [builder]
/// function. These values are obtained from active data states, one which may be the state
/// identified by [stateKey], or one of its ancestor data states.
class DataTreeStateBuilder2<D1, D2> extends _BaseDataTreeStateBuilder {
  DataTreeStateBuilder2({
    Key? key,
    required StateKey stateKey,
    required DataTreeStateWidgetBuilder2<D1, D2> builder,
    StateKey? dataStateKey1,
    StateKey? dataStateKey2,
  }) : super(
            key,
            stateKey,
            [
              StateDataResolver<D1>(dataStateKey1),
              StateDataResolver<D2>(dataStateKey2),
            ],
            (context, dataList, currentState) => builder(
                  context,
                  dataList.getAs<D1>(0),
                  dataList.getAs<D2>(1),
                  currentState,
                ));
}

/// A widget that builds itself, using tree state data, itself when a specific tree state is an
/// active state in a [TreeStateMachine].
///
/// The tree state for which this widget builds itself is identified by [stateKey]. If this state
/// is an active state in the state machine, the [builder] function is called to obtain the widget
/// to display.
///
/// The type parameters [D1], [D2] and [D3] indicate the types of state data that is provided to the
/// [builder] function. These values are obtained from active data states, one which may be the state
/// identified by [stateKey], or one of its ancestor data states.
class DataTreeStateBuilder3<D1, D2, D3> extends _BaseDataTreeStateBuilder {
  DataTreeStateBuilder3({
    Key? key,
    required StateKey stateKey,
    required DataTreeStateWidgetBuilder3<D1, D2, D3> builder,
    StateKey? dataStateKey1,
    StateKey? dataStateKey2,
    StateKey? dataStateKey3,
  }) : super(
            key,
            stateKey,
            [
              StateDataResolver<D1>(dataStateKey1),
              StateDataResolver<D2>(dataStateKey2),
              StateDataResolver<D3>(dataStateKey3),
            ],
            (context, dataList, currentState) => builder(
                  context,
                  dataList.getAs<D1>(0),
                  dataList.getAs<D2>(1),
                  dataList.getAs<D3>(2),
                  currentState,
                ));
}

class _TreeStateBuilderState extends State<_BaseDataTreeStateBuilder> {
  StreamSubscription? _combinedDataSubscription;
  StreamSubscription? _activeDescendantSubscription;
  List<dynamic>? _stateDataList;
  AsyncError? _error;
  late final Logger _logger = Logger('_TreeStateBuilderState.${widget.stateKey}');

  @override
  void didUpdateWidget(_BaseDataTreeStateBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stateKey != oldWidget.stateKey ||
        !_areResolversEqual(oldWidget.stateDataResolvers)) {
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
  Widget build(BuildContext context) {
    var stateMachineContext = TreeStateMachineProvider.of(context);
    assert(stateMachineContext != null);
    assert(_stateDataList != null);
    return _error != null
        ? ErrorWidget(_error!)
        : widget._widgetBuilder(context, _stateDataList!, stateMachineContext!.currentState);
  }

  void _subscribe() {
    var stateMachineContext = TreeStateMachineProvider.of(context);
    assert(stateMachineContext != null);

    var currentState = stateMachineContext!.currentState;
    if (!currentState.isInState(widget.stateKey)) return;

    var initialValues = <dynamic>[];
    var dataStreams = widget.stateDataResolvers
        .map((resolve) {
          var stream = resolve(currentState);
          assert(stream != null, 'Data stream for state ${resolve.stateKey} could not be resolved');
          assert(stream!.hasValue, 'A resolved data stream should have a value');
          if (stream != null) initialValues.add(stream.value);
          return stream;
        })
        .where((stream) {
          return stream != null;
        })
        .cast<ValueStream>()
        .toList();

    var combinedDataStream = StreamCombineLatest(dataStreams);
    _stateDataList = initialValues.toList();
    _combinedDataSubscription = combinedDataStream.listen(
      (stateDataValues) {
        setState(() => _stateDataList = stateDataValues);
      },
      onError: (err, stackTrace) {
        setState(() => _error = AsyncError(err, stackTrace));
      },
      onDone: () => {
        _logger.finer(
            'CombineLatestDone for data streams ${widget.stateDataResolvers.map((e) => e.stateKey.toString()).join(', ')}')
      },
    );
  }

  void _unsubscribe() {
    _combinedDataSubscription?.cancel();
    _activeDescendantSubscription?.cancel();
  }

  bool _areResolversEqual(List<StateDataResolver> otherResolvers) {
    var resolvers = widget.stateDataResolvers;
    if (otherResolvers.length == widget.stateDataResolvers.length) {
      for (var i = 0; i < otherResolvers.length; i++) {
        if (otherResolvers[i] != resolvers[i]) return false;
      }
      return true;
    }
    return false;
  }
}

extension _ListExtensions on List<dynamic> {
  T getAs<T>(int index) {
    return const _TypeLiteral<void>().type == T ? null as T : this[index] as T;
  }
}

class _TypeLiteral<T> {
  const _TypeLiteral();
  Type get type => T;
}

// Helper class to re-use resolver instances so that that we don't do extraneous work in
// _TreeStateBuilderState.didUpdateWidget
class StateDataResolver<D> {
  final StateKey? stateKey;
  static final _resolversByType = <String, StateDataResolver>{};
  StateDataResolver._(this.stateKey);

  factory StateDataResolver([StateKey? stateKey]) {
    var key = '$stateKey-$D';
    var resolver = _resolversByType[key];
    if (resolver == null) {
      resolver = StateDataResolver<D>._(stateKey);
      _resolversByType[key] = resolver;
    }
    return resolver as StateDataResolver<D>;
  }

  ValueStream? call(CurrentState currentState) => currentState.data<D>(stateKey);
}
