import 'package:rohd/rohd.dart';

class Timer extends Module {
  final int width;

  Logic get val => output('val');
  Logic get interrupt => output('interrupt');
  Logic get elapsed => output('elapsed');

  Logic wasStarted = Logic();
  Logic restart = Logic();

  Timer({
    required Logic clk,
    required Logic reset,
    required Logic start,
    required Logic continuous,
    required Logic stop,
    required Logic saturation,
    this.width = 8,
  }) {
    clk = addInput('clk', clk);
    reset = addInput('reset', reset);
    start = addInput('start', start);
    continuous = addInput('continuous', continuous);
    stop = addInput('stop', stop);
    saturation = addInput('saturation', saturation, width: width);
    addOutput('val', width: width);
    addOutput('interrupt');
    addOutput('elapsed', width: width);

    restart <= val.eq(saturation - 1);

    interrupt <= flop(clk, reset: reset | stop, restart);

    val <=
        flop(
          clk,
          reset: reset | (restart & continuous),
          en: start & ~stop & ~restart,
          val + 1,
        );

    wasStarted <= flop(clk, reset: reset, start);

    elapsed <=
        flop(
            clk,
            reset: reset | (start & ~wasStarted),
            en: val.eq(saturation - 1) & continuous,
            elapsed + 1);
  }
}
