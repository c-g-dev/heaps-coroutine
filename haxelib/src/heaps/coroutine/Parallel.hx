package heaps.coroutine;

import heaps.coroutine.Coroutine;

class Parallel extends CoroutineObject {
	var children:Array<Coroutine> = [];

	public function new(?coros:Array<Coroutine>) {
		super();
		if (coros != null) {
			for (coro in coros) {
				children.push(coro);
			}
		}
	}

	var allComplete:Future<Array<Dynamic>> = null;

	private function onFrame(ctx:CoroutineContext):FrameYield {
		ctx.once(() -> {
			for (child in children) {
				child.start();
			}
			allComplete = Future.all(children.map((child) -> child.context().future));
		});

		allComplete.await();

		return Stop;
	}
}
