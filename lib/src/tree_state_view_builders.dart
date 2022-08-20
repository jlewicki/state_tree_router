import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tree_state_machine/async.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import './current_tree_state_provider.dart';

typedef BuildTreeStateView = Widget Function(
    BuildContext context, _StateDataList _stateDataList, CurrentState currentState);

typedef CurrentDescendantChanged = void Function(StateKey descendantKey, CurrentState currentState);

abstract class _TreeStateViewBuilderBase extends StatefulWidget {
  const _TreeStateViewBuilderBase({
    Key? key,
    required this.stateKey,
    required this.builder,
    this.onCurrentDescendantChanged,
  }) : super(key: key);

  final StateKey stateKey;
  final BuildTreeStateView builder;
  final CurrentDescendantChanged? onCurrentDescendantChanged;
  List<_DataStreamResolver> get _dataStreamResolvers;
}

class _TreeStateViewBuilderBaseState extends State<_TreeStateViewBuilderBase> {
  _TreeStateViewBuilderBaseState();

  StreamSubscription? _combinedDataSubscription;
  StreamSubscription? _activeDescendantSubscription;
  _StateDataList? _stateDataList;
  AsyncError? _error;

  @override
  void didUpdateWidget(_TreeStateViewBuilderBase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stateKey != oldWidget.stateKey ||
        !_areResolversEqual(oldWidget._dataStreamResolvers) ||
        widget.onCurrentDescendantChanged != oldWidget.onCurrentDescendantChanged) {
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
    var stateMachineContext = CurrentTreeStateProvider.of(context);
    assert(stateMachineContext != null);
    assert(_stateDataList != null);
    return _error != null
        ? ErrorWidget(_error!)
        : widget.builder(context, _stateDataList!, stateMachineContext!.currentState);
  }

  void _subscribe() {
    var stateMachineContext = CurrentTreeStateProvider.of(context);
    assert(stateMachineContext != null);

    var currentState = stateMachineContext!.currentState;
    if (!currentState.isInState(widget.stateKey)) return;

    var stateMachine = currentState.stateMachine;
    var currentDescendantStream = stateMachine.transitions
        .where((t) => !t.exitPath.contains(widget.stateKey))
        .map((t) => t.to);

    if (widget.onCurrentDescendantChanged != null) {
      _activeDescendantSubscription = currentDescendantStream.listen(
        (descendantKey) => widget.onCurrentDescendantChanged!(descendantKey, currentState),
      );
    }

    var initialValues = <dynamic>[];
    var dataStreams = widget._dataStreamResolvers
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
    _stateDataList = _StateDataList(initialValues);
    _combinedDataSubscription = combinedDataStream.listen(
      (stateDataValues) {
        setState(() {
          _stateDataList = _StateDataList(stateDataValues);
        });
      },
      onError: (err, stackTrace) {
        setState(() {
          _error = AsyncError(err, stackTrace);
        });
      },
      onDone: () => {
        print(
            'CombineLatestDone for data streams ${widget._dataStreamResolvers.map((e) => e.stateKey.toString()).join(', ')}')
      },
    );
  }

  void _unsubscribe() {
    _combinedDataSubscription?.cancel();
    _activeDescendantSubscription?.cancel();
  }

  bool _areResolversEqual(List<_DataStreamResolver> otherResolvers) {
    var resovlers = widget._dataStreamResolvers;
    if (otherResolvers.length == widget._dataStreamResolvers.length) {
      for (var i = 0; i < otherResolvers.length; i++) {
        if (otherResolvers[i] != resovlers[i]) return false;
      }
      return true;
    }
    return false;
  }
}

typedef BuildTreeStateView1<D> = Widget Function(
  BuildContext context,
  D stateData,
  CurrentState currentState,
);

class TreeStateViewBuilder<D> extends _TreeStateViewBuilderBase {
  TreeStateViewBuilder({
    Key? key,
    required StateKey stateKey,
    required BuildTreeStateView1<D> builder,
    CurrentDescendantChanged? onCurrentDescendantChanged,
  })  : _dataStreamResolvers = [
          _DataStreamResolver<D>(stateKey),
        ],
        super(
            key: key,
            stateKey: stateKey,
            onCurrentDescendantChanged: onCurrentDescendantChanged,
            builder: (context, dataList, currentState) =>
                builder(context, dataList.get<D>(0), currentState));

  @override
  _TreeStateViewBuilderBaseState createState() => _TreeStateViewBuilderBaseState();

  @override
  late final List<_DataStreamResolver> _dataStreamResolvers;
}

typedef BuildTreeStateView2<D, DAnc> = Widget Function(
  BuildContext context,
  D stateData,
  DAnc ancestorData,
  CurrentState currentState,
);

class TreeStateViewBuilder2<D, DAnc> extends _TreeStateViewBuilderBase {
  TreeStateViewBuilder2({
    Key? key,
    required StateKey stateKey,
    required BuildTreeStateView2<D, DAnc> builder,
    StateKey? ancestorStateKey,
    CurrentDescendantChanged? onCurrentDescendantChanged,
  })  : _dataStreamResolvers = [
          _DataStreamResolver<D>(stateKey),
          _DataStreamResolver<DAnc>(ancestorStateKey),
        ],
        super(
            key: key,
            stateKey: stateKey,
            onCurrentDescendantChanged: onCurrentDescendantChanged,
            builder: (context, dataList, currentState) =>
                builder(context, dataList.get<D>(0), dataList.get<DAnc>(1), currentState));

  @override
  _TreeStateViewBuilderBaseState createState() => _TreeStateViewBuilderBaseState();

  @override
  final List<_DataStreamResolver> _dataStreamResolvers;
}

typedef BuildTreeStateView3<D, DAnc1, DAnc2> = Widget Function(
  BuildContext context,
  D stateData,
  DAnc1 ancestor1Data,
  DAnc2 ancestor2Data,
  CurrentState currentState,
);

class TreeStateViewBuilder3<D, DAnc1, DAnc2> extends _TreeStateViewBuilderBase {
  TreeStateViewBuilder3({
    Key? key,
    required StateKey stateKey,
    required BuildTreeStateView3<D, DAnc1, DAnc2> builder,
    StateKey? ancestor1StateKey,
    StateKey? ancestor2StateKey,
    CurrentDescendantChanged? currentDescendantChanged,
  })  : _dataStreamResolvers = [
          _DataStreamResolver<D>(stateKey),
          _DataStreamResolver<DAnc1>(ancestor1StateKey),
          _DataStreamResolver<DAnc2>(ancestor2StateKey),
        ],
        super(
            key: key,
            stateKey: stateKey,
            onCurrentDescendantChanged: currentDescendantChanged,
            builder: (context, dataList, currentState) => builder(
                  context,
                  dataList.get<D>(0),
                  dataList.get<DAnc1>(1),
                  dataList.get<DAnc2>(2),
                  currentState,
                ));
  @override
  final List<_DataStreamResolver> _dataStreamResolvers;

  @override
  _TreeStateViewBuilderBaseState createState() => _TreeStateViewBuilderBaseState();
}

class _StateDataList {
  final List<dynamic> _stateDataValues;
  _StateDataList(this._stateDataValues);
  T get<T>(int index) {
    return const _TypeLiteral<void>().type == T ? null as T : _stateDataValues[index] as T;
  }
}

class _TypeLiteral<T> {
  const _TypeLiteral();
  Type get type => T;
}

// Helper class to re-use resolver instances so that that we don't do extraneous work in
// _TreeStateViewBuilderBaseState.didUpdateWidget
class _DataStreamResolver<D> {
  final StateKey? stateKey;
  static final _resolversByType = <String, _DataStreamResolver>{};
  _DataStreamResolver._(this.stateKey);

  factory _DataStreamResolver(StateKey? stateKey) {
    var key = '$stateKey-$D';
    var resolver = _resolversByType[key];
    if (resolver == null) {
      resolver = _DataStreamResolver<D>._(stateKey);
      _resolversByType[key] = resolver;
    }
    return resolver as _DataStreamResolver<D>;
  }

  ValueStream? call(CurrentState currentState) => currentState.data<D>(stateKey);
}
