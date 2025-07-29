import heaps.coroutine.Coroutine;
import heaps.coroutine.Coroutine.CoroutineContext;
import heaps.coroutine.CoroutineSystem;
import heaps.coroutine.Coroutine.FrameYield;
import heaps.coroutine.Coro;
import heaps.coroutine.Future;
import heaps.coroutine.CoroutineSystem;

@:access(heaps.coroutine.CoroutineContext)
@:access(heaps.coroutine.CoroutineSystem)
@:access(heaps.coroutine.Future)
class CoroutineSystemTests {
	static function main() {
		trace("Starting tests");
		new CoroutineSystemTests();
	}

	public function new() {
		try {
			testWaitNextFrame();
			testWaitFrames();
			testWaitSeconds();
			testFutureCompletion();
			testAwait();
			testOnce();
			testSuspend();
			testReturn();
			testFutureThen();
			testFutureMap();
			testFutureOf();
			testFutureAll();
			testFutureAwait();
			testYield();
			testCoroYield();
			report(true);
		} catch (e) {
			trace("TEST FAILED: " + e.message + "\n" + e.stack.toString());
			report(false);
		}
	}

	inline function assert(cond:Bool, ?msg:String) {
		if (!cond)
			throw(msg == null ? "Assertion failed" : msg);
	}

	inline function runFrame(dt:Float) {
		hxd.Timer.dt = dt;
		CoroutineSystem.MAIN.update();
	}

	function testWaitNextFrame() {
		trace("testWaitNextFrame");
		var ctx:CoroutineContext = null;

		Coro.start(function(c) {
			trace("testWaitNextFrame coroutine");
			ctx = c;
			if (c.frameCount == 0)
				return WaitNextFrame;
			return Stop;
		});

		runFrame(1 / 60);
		assert(!ctx.isComplete, "ended too early");

		runFrame(1 / 60);
		assert(ctx.isComplete, "did not resume");
		assert(ctx.frameCount == 2, 'expected 2 executions, got ${ctx.frameCount}');

		trace("testWaitNextFrame   ✓");
	}

	function testWaitFrames() {
		trace("testWaitFrames");
		var ctx:CoroutineContext = null;
		var n = 5;

		Coro.start(function(c) {
			trace("testWaitFrames coroutine");
			trace("c.frameCount: " + Std.int(c.frameCount));
			ctx = c;
			if (c.frameCount == 0)
				return WaitFrames(n - 1);
			return Stop;
		});

		for (i in 0...n)
			runFrame(1 / 60);

		assert(!ctx.isComplete, "finished too soon");
		assert(ctx.frameCount == n);

		runFrame(1 / 60);
		assert(ctx.isComplete, "did not finish after n frames");

		trace("testWaitFrames      ✓");
	}

	function testWaitSeconds() {
		trace("testWaitSeconds");
		var ctx:CoroutineContext = null;

		Coro.start(function(c) {
			trace("testWaitSeconds coroutine");
			ctx = c;
			trace("c.timeToWait : " + Std.int(c.timeToWait));
			if (c.frameCount == 0)
				return WaitSeconds(1.0);
			return Stop;
		});

		for (i in 0...5)
			runFrame(0.2);
		assert(!ctx.isComplete, "finished after 0.8 s");

		runFrame(0.2);
		trace("c.timeToWait : " + ctx.timeToWait);
		runFrame(0.1);
		trace("c.timeToWait : " + ctx.timeToWait);
		runFrame(0.1);
		trace("c.timeToWait : " + ctx.timeToWait);
		assert(ctx.isComplete, "did not finish after 1.0 s");

		trace("testWaitSeconds     ✓");
	}

	function testFutureCompletion() {
		trace("testFutureCompletion");
		var ctx:CoroutineContext = null;
		var received = -1;

		Coro.start(function(c) {
			ctx = c;
			c.result = 42;
			return Stop;
		});

		runFrame(1 / 60);

		@:privateAccess assert(ctx.isComplete);
		@:privateAccess assert(ctx.result == 42);

		@:privateAccess ctx.future.then(v -> received = v);
		@:privateAccess assert(ctx.future.isComplete, "future not complete");
		assert(received == 42, 'future value = $received');

		trace("testFutureCompletion ✓");
	}

	function testAwait() {
		trace("testAwait");
		var coro1Passed = false;
		var coro2Passed = false;
		var coro3Passed = false;

		var coro1 = Coro.defer(function(c) {
			if (c.frameCount == 0)
				return WaitFrames(5);
			coro1Passed = true;
			return Stop;
		});

		var coro2 = Coro.defer(function(c) {
			if (c.frameCount == 0)
				return WaitFrames(5);
			coro2Passed = true;
			return Stop;
		});

		var coro3 = Coro.defer(function(c) {
			if (c.frameCount == 0)
				return WaitFrames(5);
			coro3Passed = true;
			return Stop;
		});

		Coro.start(function(c) {
			coro1.await();
			coro2.await();
			coro3.await();
			return Stop;
		});

		for (i in 0...120)
			runFrame(1 / 60);
		assert(coro1Passed, "coro1 not passed");
		assert(coro2Passed, "coro2 not passed");
		assert(coro3Passed, "coro3 not passed");

		trace("testAwait          ✓");
	}

	public function testOnce() {
		trace("testOnce");
		var agg = 0;
		var agg2 = 0;
		Coro.start((ctx:CoroutineContext) -> {
			Coro.once(() -> {
				agg += 1;
			});
			agg2 = Coro.once(() -> {
				return 50 + 49;
			});
			if (ctx.frameCount < 5)
				return WaitNextFrame;
			return Stop;
		});

		for (i in 0...20)
			runFrame(1 / 60);
		assert(agg == 1, 'agg = $agg');
		assert(agg2 == 99, 'agg2 = $agg2');
		trace("testOnce           ✓");
	}

	function testSuspend() {
		trace("testSuspend");
		var ctx:CoroutineContext = null;

		var fut = new Future<Dynamic>();

		Coro.start(function(c) {
			ctx = c;
			if (c.frameCount == 0)
				return Suspend(fut);
			return Stop;
		});

		runFrame(1 / 60);
		assert(!ctx.isComplete, "completed immediately after Suspend");
		@:privateAccess assert(ctx.isWaiting, "not flagged as waiting");

		for (i in 0...10) {
			runFrame(1 / 60);
			assert(!ctx.isComplete, "resumed before the future resolved");
		}

		fut.resolve(null);

		runFrame(1 / 60);
		assert(ctx.isComplete, "did not resume after the future resolved");

		trace("testSuspend        ✓");
	}

	function testReturn() {
		trace("testReturn");
		var ctx:CoroutineContext = null;
		var received = -1;

		Coro.start(function(c) {
			ctx = c;
			return Return(12345);
		});

		runFrame(1 / 60);

		@:privateAccess assert(ctx.isComplete, "coroutine not marked complete");
		@:privateAccess assert(ctx.result == 12345, "ctx.result != 12345");

		@:privateAccess ctx.future.then(v -> received = v);
		@:privateAccess assert(ctx.future.isComplete, "future not complete");
		assert(received == 12345, 'future value = $received');

		trace("testReturn        ✓");
	}

	function testFutureThen() {
		trace("testFutureThen");
		var fut = new Future<Int>();
		var received = -1;
		fut.then(v -> received = v);
		assert(received == -1, "callback executed too early");
		fut.resolve(123);
		assert(received == 123, "callback did not receive value");
		trace("testFutureThen     ✓");
	}

	function testFutureMap() {
		trace("testFutureMap");
		var fut = new Future<Int>();
		var mapped = fut.map(v -> v * 2);
		var received = -1;
		mapped.then(v -> received = v);
		fut.resolve(21);
		assert(received == 42, "mapped future incorrect value");
		trace("testFutureMap      ✓");
	}

	function testFutureOf() {
		trace("testFutureOf");
		var fut = Future.of(99);
		var received = -1;
		fut.then(v -> received = v);
		assert(received == 99, "Future.of did not resolve immediately");
		assert(fut.isComplete, "Future.of not marked complete");
		trace("testFutureOf       ✓");
	}

	function testFutureAll() {
		trace("testFutureAll");
		var fut1 = new Future<Int>();
		var fut2 = new Future<Int>();
		var combined = Future.all([fut1, fut2]);
		var results:Array<Dynamic> = null;
		combined.then(arr -> results = arr);
		fut1.resolve(1);
		assert(results == null, "Future.all resolved too early");
		fut2.resolve(2);
		assert(results != null, "Future.all did not resolve");
		assert(results.length == 2, "Future.all results length != 2");
		trace("testFutureAll      ✓");
	}

	function testFutureAwait() {
		trace("testFutureAwait");
		var fut = new Future<Int>();
		var awaited = -1;

		Coro.start(function(c) {
			awaited = fut.await();
			return Stop;
		});

		runFrame(1 / 60);
		assert(awaited == -1, "await returned before future resolved");

		fut.resolve(777);
		runFrame(1 / 60);
		assert(awaited == 777, 'awaited value = $awaited');

		trace("testFutureAwait    ✓");

	}

	function testYield() {
		trace("testYield");
		var ctx:CoroutineContext = null;
		var executedAfterYield = 0;

		Coro.start(function (c) {
			ctx = c;
			WaitNextFrame.yield();
			executedAfterYield++;
			return Stop;
		});

		// First frame – coroutine should yield
		runFrame(1 / 60);
		assert(executedAfterYield == 0, "yield block executed in first frame");

		// Second frame – coroutine should complete and block executed once
		runFrame(1 / 60);
		assert(executedAfterYield == 1, "yield block did not execute exactly once");
		@:privateAccess assert(ctx.isComplete, "coroutine not complete after yield");

		trace("testYield          ✓");
	}

	function testCoroYield() {
		trace("testCoroYield");
		var ctx:CoroutineContext = null;
		var side = 0;

		Coro.start(function (c) {
			ctx = c;
			Coro.yield({
				side += 1;
				WaitNextFrame;
			});
			return Stop;
		});

		runFrame(1 / 60);
		assert(side == 1, "Coro.yield body did not run on first frame");
		assert(!ctx.isComplete, "coroutine completed too early");

		runFrame(1 / 60);
		assert(side == 1, "Coro.yield body executed more than once");
		@:privateAccess assert(ctx.isComplete, "coroutine did not complete after second frame");

		trace("testCoroYield      ✓");
	}

	private function report(allOk:Bool) {
		trace(allOk ? "====================================\nALL COROUTINE TESTS PASSED\n====================================" : "Some tests failed – see log above.");
	}
}
