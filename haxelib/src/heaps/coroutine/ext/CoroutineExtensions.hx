package heaps.coroutine.ext;

import heaps.coroutine.Coroutine;
import heaps.coroutine.Future;
import heaps.coroutine.CoroutineSystem;

@:access(heaps.coroutine.CoroutineContext)
@:access(heaps.coroutine.CoroutineSystem)
@:access(heaps.coroutine.Future)
class CoroutineExtensions {
	public static function start(coroutine:Coroutine):Void {
		if (coroutine.context().hasStarted)
			return;
		CoroutineSystem.MAIN.add(coroutine.context());
	}

	public static function pause(coroutine:Coroutine):Void {
		coroutine.context().manuallyPaused = true;
	}

	public static function forceStop(coroutine:Coroutine):Void {
		CoroutineSystem.MAIN.remove(coroutine.context());
	}

	public static function future(coroutine:Coroutine):Future {
		return coroutine.context().future;
	}
}
