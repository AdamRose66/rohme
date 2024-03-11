import '../example/timer_example/top.dart';
import '../example/timer_example/register_map.dart';
import '../example/timer_example/rohme_timer/rohme_hardware_timer.dart';

import 'package:rohme/rohme.dart';
import 'package:test/test.dart';

void main() {
  test('timer test', () async {
    await simulateModel(() {
      initialiseRegisterMap();
      return Top(
          'top',
          (name, parent, clockDivider) =>
              RohmeHardWareTimer(name, parent, clockDivider));
    },
        clockPeriod: SimDuration(picoseconds: 10),
        duration: SimDuration(nanoseconds: 7));
  });
}
