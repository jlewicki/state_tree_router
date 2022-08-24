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

/// A function that constructs widget that visualizes a data tree state with data type of [D].
///
/// The function is provided the current [stateData] for the state, and the [currentState] of the
/// tree state machine.
typedef TreeStateWidgetBuilder<D> = Widget Function(
  BuildContext context,
  D stateData,
  CurrentState currentState,
);

/// A function that constructs widget that visualizes a data tree state with data type of [D], using
/// data from an ancestor data tree state of with data type [DAnc].
///
/// The function is provided the current [stateData] and [ancestorStateData] for the state and its
/// ancestor, along with the [currentState] of the tree state machine.
typedef TreeStateWidgetBuilder2<D, DAnc> = Widget Function(
  BuildContext context,
  D stateData,
  DAnc ancestorStateData,
  CurrentState currentState,
);

/// A function that constructs widget that visualizes a data tree state with data type of [D], using
/// data from two ancestor data tree states of with data type [DAnc] and [DAnc2].
///
/// The function is provided the current [stateData], [ancestorStateData], and [ancestorStateData2]
/// for the state and its ancestors, along with the [currentState] of the tree state machine.
typedef TreeStateWidgetBuilder3<D, DAnc, DAnc2> = Widget Function(
  BuildContext context,
  D stateData,
  DAnc ancestorStateData,
  DAnc2 ancestorStateData2,
  CurrentState currentState,
);

abstract class _BaseTreeStateBuilder extends StatefulWidget {
  const _BaseTreeStateBuilder(
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

class TreeStateBuilder<D> extends _BaseTreeStateBuilder {
  TreeStateBuilder({
    Key? key,
    required StateKey stateKey,
    required TreeStateWidgetBuilder<D> builder,
  }) : super(
            key,
            stateKey,
            [StateDataResolver<D>(stateKey)],
            (context, dataList, currentState) => builder(
                  context,
                  dataList.getAs<D>(0),
                  currentState,
                ));
}

class TreeStateBuilder2<D, DAnc> extends _BaseTreeStateBuilder {
  TreeStateBuilder2({
    Key? key,
    required StateKey stateKey,
    required TreeStateWidgetBuilder2<D, DAnc> builder,
  }) : super(
            key,
            stateKey,
            [StateDataResolver<D>(stateKey)],
            (context, dataList, currentState) => builder(
                  context,
                  dataList.getAs<D>(0),
                  dataList.getAs<DAnc>(1),
                  currentState,
                ));
}

class TreeStateBuilder3<D, DAnc1, DAnc2> extends _BaseTreeStateBuilder {
  TreeStateBuilder3({
    Key? key,
    required StateKey stateKey,
    required TreeStateWidgetBuilder3<D, DAnc1, DAnc2> builder,
  }) : super(
            key,
            stateKey,
            [StateDataResolver<D>(stateKey)],
            (context, dataList, currentState) => builder(
                  context,
                  dataList.getAs<D>(0),
                  dataList.getAs<DAnc1>(1),
                  dataList.getAs<DAnc2>(1),
                  currentState,
                ));
}

class _TreeStateBuilderState extends State<_BaseTreeStateBuilder> {
  StreamSubscription? _combinedDataSubscription;
  StreamSubscription? _activeDescendantSubscription;
  List<dynamic>? _stateDataList;
  AsyncError? _error;
  late final Logger _logger = Logger('_TreeStateBuilderState.${widget.stateKey}');

  @override
  void didUpdateWidget(_BaseTreeStateBuilder oldWidget) {
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

extension ListExtensions on List<dynamic> {
  T getAs<T>(int index) {
    return const _TypeLiteral<void>().type == T ? null as T : this[index] as T;
  }
}

class _TypeLiteral<T> {
  const _TypeLiteral();
  Type get type => T;
}

// Helper class to re-use resolver instances so that that we don't do extraneous work in
// _TreeStateViewBuilderBaseState.didUpdateWidget
class StateDataResolver<D> {
  final StateKey? stateKey;
  static final _resolversByType = <String, StateDataResolver>{};
  StateDataResolver._(this.stateKey);

  factory StateDataResolver(StateKey? stateKey) {
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
