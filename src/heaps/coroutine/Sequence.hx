package heaps.coroutine;

import heaps.coroutine.Coroutine;

class Sequence extends CoroutineObject {
	var children:Array<Coroutine> = [];

	public function new(?coros:Array<Coroutine>) {
		super();
		if (coros != null) {
			for (coro in coros) {
				add(coro);
			}
		}
	}

	public function add(coro:Coroutine):Void {
		coro.context().runManually = true;
		children.push(coro);
	}

	private function onFrame(ctx:CoroutineContext):FrameYield {
		for (child in children) {
			if (child.context().isComplete)
				continue;
			return child.context().invoke();
		}
		return Stop;
	}
}
