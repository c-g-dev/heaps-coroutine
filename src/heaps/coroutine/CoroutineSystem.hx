package heaps.coroutine;

import heaps.coroutine.Coroutine.CoroutineContext;
import heaps.coroutine.Coroutine.CoroutinePriority;
import heaps.coroutine.Future;
import ludi.commons.collections.Stack;

@:access(heaps.coroutine.CoroutineContext)
@:access(heaps.coroutine.Future)
class CoroutineSystem {
	public static var MAIN:CoroutineSystem = new CoroutineSystem();

	var routines:Map<String, CoroutineContext> = [];
	var routinesByPriority:Map<CoroutinePriority, Array<CoroutineContext>> = [];

	var routinesToRemoveThisFrame:Array<String> = [];
	var routinesToNotifyThisFrame:Array<CoroutineContext> = [];

	var contextStack:Stack<CoroutineContext> = new Stack();

	public function new() {
		routinesByPriority[Controls] = [];
		routinesByPriority[Processing] = [];
		routinesByPriority[Rendering] = [];
	}

	var didInit:Bool = false;
	var isWiredToMainLoop:Bool = false;

	private function init() {
		if (!didInit) {
			#if coroutine_manual_wiring
			#else
			wireCoroutineSystemToMainLoop(MAIN);
			#end
			didInit = true;
		}
	}

	private static var CurrentLoopFunction:Void->Void;
	private static var RegisteredLoopFunc:Void->Void;

	private static function wireCoroutineSystemToMainLoop(system:CoroutineSystem) {
		haxe.Timer.delay(() -> {
			if ((hxd.System.getCurrentLoop() != CurrentLoopFunction) || CurrentLoopFunction == null) {
				RegisteredLoopFunc = hxd.System.getCurrentLoop();
				CurrentLoopFunction = () -> {
					RegisteredLoopFunc();
					system.update();
				}
				hxd.System.setLoop(CurrentLoopFunction);
				system.isWiredToMainLoop = true;
			}
		}, 0);
	}

	public function update() {
		var dt:Float = hxd.Timer.dt;

		for (arr in routinesByPriority) {
			for (ctx in arr) {
				if (!ctx.hasStarted) {
					ctx.hasStarted = true;
					if (ctx.onStart != null)
						ctx.onStart();
				}

				if (shouldFireThisFrame(ctx, dt)) {
					ctx.invoke();
				}

				ctx.frameCount++;
			}
		}

		for (id in routinesToRemoveThisFrame) {
			var ctx = routines[id];
			if (ctx != null) {
				routines.remove(id);
				routinesByPriority[ctx.priority].remove(ctx);
			}
		}
		routinesToRemoveThisFrame.resize(0);

		for (ctx in routinesToNotifyThisFrame) {
			ctx.future.resolve(ctx.result);
		}
		routinesToNotifyThisFrame.resize(0);
	}

	public function add<T>(ctx:CoroutineContext<T>):Void {
		init();
		ctx.system = this;
		routines[ctx.uuid] = ctx;
		routinesByPriority[ctx.priority].push(ctx);
	}

	public function remove(ctx:CoroutineContext):Void {
		if (ctx == null)
			return;
		routines.remove(ctx.uuid);
		routinesByPriority[ctx.priority].remove(ctx);
	}

	private inline function shouldFireThisFrame(ctx:CoroutineContext, dt:Float):Bool {
		if (ctx.manuallyPaused)
			return false;
		if (ctx.lastResult == null)
			return true;
		if (ctx.runManually)
			return false;

		switch ctx.lastResult {
			case Stop:
				return false;
			case WaitNextFrame:
				return true;
			case WaitFrames(_):
				if (ctx.framesToWait > 0) {
					ctx.framesToWait -= 1;
					return false;
				}
				return true;
			case WaitSeconds(_):
				if (ctx.timeToWait > 0) {
					ctx.timeToWait -= dt;
					return false;
				}
				return true;
			case Return(_):
				return true;
			case Suspend(_):
				return !ctx.isWaiting;
		}
	}
}
