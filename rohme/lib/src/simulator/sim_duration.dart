// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Copyright Adam Rose 2024
//
// Amended by Adam Rose to add extra resolution to enable the modelling of
// digital hardware systems.
//

extension PicoSecondDuration on Duration {
  /// converts a [Duration] to picoseconds, to enable [Duration] to [SimDuration]
  /// conversion
  int get inPicoseconds {
    // ignore: unnecessary_this
    return this.inMicroseconds * SimDuration.picosecondsPerMicrosecond;
  }
}

/// A clone of [Duration] which provides picosecond granularity
///
/// This is used by [Simulator] for simulating digital systems, which require
/// finer time resolution than is needed for normal Dart programs.
class SimDuration implements Duration {
  /// The number of picoseconds per nanosecond.
  static const int picosecondsPerNanosecond = 1000;

  /// The number of nanoseconds per microsecond.
  static const int nanosecondsPerMicrosecond = 1000;

  /// The number of microseconds per millisecond.
  static const int microsecondsPerMillisecond = 1000;

  /// The number of milliseconds per second.
  static const int millisecondsPerSecond = 1000;

  /// The number of seconds per minute.
  ///
  /// Notice that some minutes of official clock time might
  /// differ in length because of leap seconds.
  /// The [SimDuration] and [DateTime] classes ignore leap seconds
  /// and consider all minutes to have 60 seconds.
  static const int secondsPerMinute = 60;

  /// The number of minutes per hour.
  static const int minutesPerHour = 60;

  /// The number of hours per day.
  ///
  /// Notice that some days may differ in length because
  /// of time zone changes due to daylight saving.
  /// The [SimDuration] class is time zone agnostic and
  /// considers all days to have 24 hours.
  static const int hoursPerDay = 24;

  /// The number of picoseconds per Microsecond
  static const int picosecondsPerMicrosecond =
      picosecondsPerNanosecond * nanosecondsPerMicrosecond;

  /// The number of picoseconds per Millisecond
  static const int picosecondsPerMillisecond =
      picosecondsPerMicrosecond * microsecondsPerMillisecond;

  /// The number of picoseconds per second
  static const int picosecondsPerSecond =
      picosecondsPerMillisecond * millisecondsPerSecond;

  /// The number of picoseconds per minute
  static const int picosecondsPerMinute =
      picosecondsPerSecond * secondsPerMinute;

  /// The number of picoseconds per hour
  static const int picosecondsPerHour = picosecondsPerMinute * minutesPerHour;

  /// The number of picoseconds per day
  static const int picosecondsPerDay = picosecondsPerHour * hoursPerDay;

  /// The number of microseconds per second.
  static const int microsecondsPerSecond =
      microsecondsPerMillisecond * millisecondsPerSecond;

  /// The number of microseconds per minute.
  static const int microsecondsPerMinute =
      microsecondsPerSecond * secondsPerMinute;

  /// The number of microseconds per hour.
  static const int microsecondsPerHour = microsecondsPerMinute * minutesPerHour;

  /// The number of microseconds per day.
  static const int microsecondsPerDay = microsecondsPerHour * hoursPerDay;

  /// The number of milliseconds per minute.
  static const int millisecondsPerMinute =
      millisecondsPerSecond * secondsPerMinute;

  /// The number of milliseconds per hour.
  static const int millisecondsPerHour = millisecondsPerMinute * minutesPerHour;

  /// The number of milliseconds per day.
  static const int millisecondsPerDay = millisecondsPerHour * hoursPerDay;

  /// The number of seconds per hour.
  static const int secondsPerHour = secondsPerMinute * minutesPerHour;

  /// The number of seconds per day.
  static const int secondsPerDay = secondsPerHour * hoursPerDay;

  /// The number of minutes per day.
  static const int minutesPerDay = minutesPerHour * hoursPerDay;

  /// An empty SimDuration, representing zero time.
  static const SimDuration zero = SimDuration(seconds: 0);

  /// The total microseconds of this [SimDuration] object.
  final int _simDuration;

  /// Creates a new [SimDuration] object whose value
  /// is the sum of all individual parts.
  ///
  /// Individual parts can be larger than the number of those
  /// parts in the next larger unit.
  /// For example, [hours] can be greater than 23.
  /// If this happens, the value overflows into the next larger
  /// unit, so 26 [hours] is the same as 2 [hours] and
  /// one more [days].
  /// Likewise, values can be negative, in which case they
  /// underflow and subtract from the next larger unit.
  ///
  /// If the total number of microseconds cannot be represented
  /// as an integer value, the number of microseconds might overflow
  /// and be truncated to a smaller number of bits,
  /// or it might lose precision.
  ///
  /// All arguments are 0 by default.
  /// ```dart
  /// const SimDuration = SimDuration(days: 1, hours: 8, minutes: 56, seconds: 59,
  ///   milliseconds: 30, microseconds: 10);
  /// print(SimDuration); // 32:56:59.030010
  /// ```
  const SimDuration(
      {int days = 0,
      int hours = 0,
      int minutes = 0,
      int seconds = 0,
      int milliseconds = 0,
      int microseconds = 0,
      int nanoseconds = 0,
      int picoseconds = 0})
      : this._picoseconds(picoseconds +
            picosecondsPerNanosecond * nanoseconds +
            picosecondsPerMicrosecond * microseconds +
            picosecondsPerMillisecond * milliseconds +
            picosecondsPerSecond * seconds +
            picosecondsPerMinute * minutes +
            picosecondsPerHour * hours +
            picosecondsPerDay * days);

  SimDuration.fromDuration(Duration d) : this(microseconds: d.inMicroseconds);

  // Fast path internal direct constructor to avoids the optional arguments
  // and [_picoseconds] recomputation.
  // The `+ 0` prevents -0.0 on the web, if the incoming SimDuration happens to be -0.0.
  const SimDuration._picoseconds(int duration) : _simDuration = duration + 0;

  /// Adds this SimDuration and [other] and
  /// returns the sum as a new SimDuration object.
  @override
  SimDuration operator +(Duration other) {
    if (other is SimDuration) {
      return SimDuration._picoseconds(_simDuration + other._simDuration);
    } else {
      return SimDuration._picoseconds(_simDuration + other.inPicoseconds);
    }
  }

  /// Subtracts [other] from this SimDuration and
  /// returns the difference as a new SimDuration object.
  @override
  SimDuration operator -(Duration other) {
    if (other is SimDuration) {
      return SimDuration._picoseconds(_simDuration - other._simDuration);
    } else {
      return SimDuration._picoseconds(_simDuration - other.inPicoseconds);
    }
  }

  /// Multiplies this SimDuration by the given [factor] and returns the result
  /// as a new SimDuration object.
  ///
  /// Note that when [factor] is a double, and the SimDuration is greater than
  /// 53 bits, precision is lost because of double-precision arithmetic.
  @override
  SimDuration operator *(num factor) {
    return SimDuration._picoseconds((_simDuration * factor).round());
  }

  /// Divides this SimDuration by the given [quotient] and returns the truncated
  /// result as a new SimDuration object.
  ///
  /// The [quotient] must not be `0`.
  @override
  SimDuration operator ~/(int quotient) {
    // By doing the check here instead of relying on "~/" below we get the
    // exception even with dart2js.
    // ignore: deprecated_member_use
    if (quotient == 0) throw IntegerDivisionByZeroException();
    return SimDuration._picoseconds(_simDuration ~/ quotient);
  }

  /// Whether this [SimDuration] is shorter than [other].
  @override
  bool operator <(Duration other) {
    if (other is SimDuration) {
      return _simDuration < other._simDuration;
    } else {
      return _simDuration < other.inPicoseconds;
    }
  }

  /// Whether this [SimDuration] is longer than [other].
  @override
  bool operator >(Duration other) {
    if (other is SimDuration) {
      return _simDuration > other._simDuration;
    } else {
      return _simDuration > other.inPicoseconds;
    }
  }

  /// Whether this [SimDuration] is shorter than or equal to [other].
  @override
  bool operator <=(Duration other) {
    if (other is SimDuration) {
      return _simDuration <= other._simDuration;
    } else {
      return _simDuration <= other.inPicoseconds;
    }
  }

  /// Whether this [SimDuration] is longer than or equal to [other].
  @override
  bool operator >=(Duration other) {
    if (other is SimDuration) {
      return _simDuration >= other._simDuration;
    } else {
      return _simDuration >= other.inPicoseconds;
    }
  }

  /// The number of entire days spanned by this [SimDuration].
  ///
  /// For example, a SimDuration of four days and three hours
  /// has four entire days.
  /// ```dart
  /// const SimDuration = SimDuration(days: 4, hours: 3);
  /// print(SimDuration.inDays); // 4
  /// ```
  @override
  int get inDays => _simDuration ~/ SimDuration.picosecondsPerDay;

  /// The number of entire hours spanned by this [SimDuration].
  ///
  /// The returned value can be greater than 23.
  /// For example, a SimDuration of four days and three hours
  /// has 99 entire hours.
  /// ```dart
  /// const SimDuration = SimDuration(days: 4, hours: 3);
  /// print(SimDuration.inHours); // 99
  /// ```
  @override
  int get inHours => _simDuration ~/ SimDuration.picosecondsPerHour;

  /// The number of whole minutes spanned by this [SimDuration].
  ///
  /// The returned value can be greater than 59.
  /// For example, a SimDuration of three hours and 12 minutes
  /// has 192 minutes.
  /// ```dart
  /// const SimDuration = SimDuration(hours: 3, minutes: 12);
  /// print(SimDuration.inMinutes); // 192
  /// ```
  @override
  int get inMinutes => _simDuration ~/ SimDuration.picosecondsPerMinute;

  /// The number of whole seconds spanned by this [SimDuration].
  ///
  /// The returned value can be greater than 59.
  /// For example, a SimDuration of three minutes and 12 seconds
  /// has 192 seconds.
  /// ```dart
  /// const SimDuration = SimDuration(minutes: 3, seconds: 12);
  /// print(SimDuration.inSeconds); // 192
  /// ```
  @override
  int get inSeconds => _simDuration ~/ SimDuration.picosecondsPerSecond;

  /// The number of whole milliseconds spanned by this [SimDuration].
  ///
  /// The returned value can be greater than 999.
  /// For example, a SimDuration of three seconds and 125 milliseconds
  /// has 3125 milliseconds.
  /// ```dart
  /// const SimDuration = SimDuration(seconds: 3, milliseconds: 125);
  /// print(SimDuration.inMilliseconds); // 3125
  /// ```
  @override
  int get inMilliseconds =>
      _simDuration ~/ SimDuration.picosecondsPerMillisecond;

  /// The number of whole microseconds spanned by this [SimDuration].
  ///
  /// The returned value can be greater than 999999.
  /// For example, a SimDuration of three seconds, 125 milliseconds and
  /// 369 microseconds has 3125369 microseconds.
  /// ```dart
  /// const SimDuration = SimDuration(seconds: 3, milliseconds: 125,
  ///     microseconds: 369);
  /// print(SimDuration.inMicroseconds); // 3125369
  /// ```
  @override
  int get inMicroseconds =>
      _simDuration ~/ SimDuration.picosecondsPerMicrosecond;

  /// The number of whole nanoseconds spanned by this [SimDuration].
  int get inNanoseconds =>
      _simDuration ~/ SimDuration.nanosecondsPerMicrosecond;

  /// The number of whole picoseconds spanned by this [SimDuration].
  int get inPicoseconds => _simDuration;

  /// Whether this [SimDuration] has the same length as [other].
  ///
  /// SimDurations have the same length if they have the same number
  /// of picoseconds, as reported by [inPicoseconds].
  @override
  bool operator ==(Object other) {
    if (other is SimDuration) {
      return _simDuration == other._simDuration;
    } else if (other is Duration) {
      return _simDuration == other.inPicoseconds;
    }
    return false;
  }

  @override
  int get hashCode => _simDuration.hashCode;

  /// Compares this [SimDuration] to [other], returning zero if the values are equal.
  ///
  /// Returns a negative integer if this [SimDuration] is shorter than
  /// [other], or a positive integer if it is longer.
  ///
  /// A negative [SimDuration] is always considered shorter than a positive one.
  ///
  /// It is always the case that `SimDuration1.compareTo(SimDuration2) < 0` iff
  /// `(someDate + SimDuration1).compareTo(someDate + SimDuration2) < 0`.
  @override
  int compareTo(Duration other) {
    if (other is SimDuration) {
      return _simDuration.compareTo(other._simDuration);
    } else {
      return _simDuration.compareTo(other.inPicoseconds);
    }
  }

  /// Returns a string representation of this [SimDuration].
  ///
  /// Returns a string with hours, minutes, seconds, and microseconds, in the
  /// following format: `H:MM:SS.mmmmmm`. For example,
  /// ```dart
  /// var d = const SimDuration(days: 1, hours: 1, minutes: 33, microseconds: 500);
  /// print(d.toString()); // 25:33:00.000500
  ///
  /// d = const SimDuration(hours: 1, minutes: 10, microseconds: 500);
  /// print(d.toString()); // 1:10:00.000500
  /// ```
  @override
  String toString() {
    String durationString = Duration(microseconds: inMicroseconds).toString();

    var picoseconds = inPicoseconds;
    picoseconds = picoseconds.remainder(picosecondsPerMicrosecond);

    if (picoseconds == 0) {
      return durationString;
    }

    var picosecondsText = picoseconds.toString().padLeft(6, "0");

    return "$durationString." "$picosecondsText";
  }

  /// Whether this [SimDuration] is negative.
  ///
  /// A negative [SimDuration] represents the difference from a later time to an
  /// earlier time.
  @override
  bool get isNegative => _simDuration < 0;

  /// Creates a new [SimDuration] representing the absolute length of this
  /// [SimDuration].
  ///
  /// The returned [SimDuration] has the same length as this one, but is always
  /// positive where possible.
  @override
  SimDuration abs() => SimDuration._picoseconds(_simDuration.abs());

  /// Creates a new [SimDuration] with the opposite direction of this [SimDuration].
  ///
  /// The returned [SimDuration] has the same length as this one, but will have the
  /// opposite sign (as reported by [isNegative]) as this one where possible.
  // Using subtraction helps dart2js avoid negative zeros.
  @override
  SimDuration operator -() => SimDuration._picoseconds(0 - _simDuration);
}
