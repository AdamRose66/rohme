/*
Copyright 2024 Adam Rose

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import 'dart:async';

enum SignalState { set, triggered }

/// A read interface for a [Signal]
abstract interface class SignalReadIf {
  /// gets the current value of the signal
  int get currentValue;

  /// gets the previous value of the signal
  int get previousValue;

  /// A Future which completes when the value of a [Signal] has changed
  ///
  /// By default, it will complete on any value alwaysAt. Use a non default
  /// [filter] function to control which alwaysAts return a completion
  ///
  /// ```dart
  /// Port<SignalReadIf> readPort;
  ///
  /// await readPort.changed();
  /// await readPort.changed( posEdge );
  ///
  /// await readPort.changed( ( s ) => s.previousValue == 4 &&
  ///                                  s.currentValue == 15 );
  /// ```
  Future<void> changed([bool Function(Signal) filter = anyEdge]);

  /// Function [f] is called whenever a [Signal] changes value as specified by
  /// filter
  ///
  /// By default, f is always called. Use a non default [filter] function to
  /// control which changes trigger a call to f().
  /// ```dart
  /// Port<SignalReadIf> readPort;
  /// readPort.alwaysAt( printAnyChange );
  /// readPort.alwaysAt( printOnPosEdge , posEdge );
  ///
  /// readPort.alwaysAt( customPrint ,
  ///                   ( s ) => s.previousValue == 4 && s.currentValue == 15 );
  /// ```
  void alwaysAt(void Function(Signal) f,
      [bool Function(Signal) filter = anyEdge]);
}

/// a write interface for a [Signal]
abstract interface class SignalWriteIf {
  /// gets the current value of the signal
  int get currentValue;

  /// gets the previous value of the signal
  int get previousValue;

  /// Updates the value of the signal in the next delta cycle.
  ///
  /// Although this is Future, the usual use case is NOT to await it:
  ///
  /// Equivalent to SV '<='
  /// ```dart
  /// Port<SignalReadIf> writePort;
  /// Duration duration = Duration( microseconds: 1 );
  /// ...
  /// while( true ) {
  ///   writePort.nba( writePort.currentValue == 0 ? 1 : 0 );
  ///   Future.Delayed( duration );
  /// }
  /// ```
  Future<void> nba(int v);
}

/// a standard filter to detect any edge
bool anyEdge(Signal s) => true;

/// a standard filter to detect positive edges
bool posEdge(Signal s) => s.previousValue == 0 && s.currentValue != 0;

/// a standard filter to detect negative edges
bool negEdge(Signal s) => s.previousValue != 0 && s.currentValue == 0;

/// This Signal class is a 64 bit Signal
///
/// It is intended as a proof of concept rather than a complete equivalent for
/// SystemVerilog writes and registers. It shows how to use the Dart event
/// wheel to implement non blocking assigment.
///
/// For more details on the overridden interfaces, please see the documentation
/// in [SignalReadIf] and [SignalWriteIf].
///
/// The [nba] method uses scheduleMicrotask to do the value update before the
/// next delta cycle, and then actually triggers the completers and callbacks
/// in the next delta cycle, after a delay of Duration.zero.
///
class Signal implements SignalReadIf, SignalWriteIf {
  @override
  int get currentValue => _currentValue;

  @override
  int get previousValue => _previousValue;

  @override
  Future<void> changed([bool Function(Signal) filter = anyEdge]) {
    Completer<void> completer = Completer();
    _alwaysAtCompleters.add((completer, filter));
    return completer.future;
  }

  @override
  void alwaysAt(void Function(Signal) f,
      [bool Function(Signal) filter = anyEdge]) {
    _alwaysFunctions.add((f, filter));
  }

  void _update(int v) {
    if (v != _currentValue) {
      if (_signalState == SignalState.set && v != _currentValue) {
        throw ArgumentError.value(v,
            'multiple nba : previous is $_previousValue , current is $_currentValue');
      }

      _previousValue = _currentValue;
      _currentValue = v;

      _signalState = SignalState.set;
    }
  }

  void _trigger() {
    if (_signalState == SignalState.triggered) {
      return;
    }

    _signalState = SignalState.triggered;

    // ignore: avoid_function_literals_in_foreach_calls
    _alwaysAtCompleters.forEach((item) {
      Completer<void> completer;
      bool Function(Signal) filter;

      (completer, filter) = item;

      if (filter(this)) {
        completer.complete();
      }
    });

    _alwaysAtCompleters.removeWhere((item) {
      // ignore: unused_local_variable
      Completer<void> completer;
      bool Function(Signal) filter;

      (completer, filter) = item;

      return filter(this);
    });

    // ignore: avoid_function_literals_in_foreach_calls
    _alwaysFunctions.forEach((item) {
      void Function(Signal) callback;
      bool Function(Signal) filter;

      (callback, filter) = item;
      if (filter(this)) {
        callback(this);
      }
    });
  }

  @override
  Future<void> nba(int v) async {
    // ensure update happens before next delta
    scheduleMicrotask(() {
      _update(v);
    });

    // wait a delta ( but since this is a Future, return control to caller )
    await Future.delayed(Duration.zero);

    // trigger the consequences of any nba in the 'next' delta
    _trigger();
  }

  int _previousValue = 0;
  int _currentValue = 0;
  SignalState _signalState = SignalState.triggered;

  final List<(void Function(Signal), bool Function(Signal))> _alwaysFunctions =
      [];
  final List<(Completer<void>, bool Function(Signal))> _alwaysAtCompleters = [];
}
