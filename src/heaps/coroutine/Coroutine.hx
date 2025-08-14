package heaps.coroutine;

import heaps.coroutine.ext.CoroutineExtensions;
import haxe.extern.EitherType;
import haxe.ds.Either;
import heaps.coroutine.ds.MaybeReturn;
import ludi.commons.collections.Stack;
import hxd.Timer;
import hxd.System;

typedef CoroutineBaseFunction<T = Dynamic> = (ctx:CoroutineContext<T>) -> FrameYield<T>;

abstract class CoroutineObject<T = Dynamic> extends CoroutineContext<T> {
	public function new() {
		super(onFrame);
	}

	private abstract function onFrame(ctx:CoroutineContext<T>):FrameYield<T>;

	public function start(): Future<T> {
		CoroutineSystem.MAIN.add(this);
		return this.future;
	}
}

abstract CoroutineFunction<T = Dynamic>(CoroutineBaseFunction<T>) from CoroutineBaseFunction<T> to CoroutineBaseFunction<T> {
	public inline function new(coro:CoroutineBaseFunction<T>) {
		this = coro;
	}

	@:from
	public static inline function fromVoid2Void<T>(func:Void->Void):CoroutineFunction<T> {
		return new CoroutineFunction((_) -> {
			func();
			return Stop;
		});
	}

	@:from
	public static inline function fromVoid2FrameYield<T>(func:Void->FrameYield<T>):CoroutineFunction<T> {
		return new CoroutineFunction((_) -> {
			return func();
		});
	}

	@:from
	public static inline function fromDt2FrameYield<T>(func:Float->FrameYield<T>):CoroutineFunction<T> {
		return new CoroutineFunction((ctx) -> {
			return func(ctx.dt);
		});
	}
}

@:using(heaps.coroutine.ext.CoroutineExtensions)
@:using(heaps.coroutine.macros.CoroutineMacroExtensions)
@:access(heaps.coroutine.CoroutineContext)
abstract Coroutine<T = Dynamic>(CoroutineContext<T>) {
	public function new(coro:EitherType<CoroutineFunction<T>, CoroutineContext<T>>) {
		if (coro is CoroutineContext) {
			this = coro;
		} else {
			this = new CoroutineContext(coro);
		}
	}

	public inline function context():CoroutineContext<T>
		return this;
}

@:access(heaps.coroutine.CoroutineSystem)
class CoroutineContext<T = Dynamic> {
	public var uuid(default, null):String;

	public var dt(get, null):Float;
	public var elapsed(default, null):Float = 0;
	public var frameCount(default, null):Int = 0;
	public var hasStarted(default, null):Bool = false;
	public var isWaiting(default, null):Bool = false;
	public var isComplete(default, null):Bool = false;

	var coro:CoroutineBaseFunction<T>;
	var framesToWait:Int = 0;
	var timeToWait:Float = 0;
	var manuallyPaused:Bool = false;
	var runManually:Bool = false;
	public var future(default, null):Future<T>;
	var onStart:Void->Void = null;
	var result(default, null):Dynamic;
	var priority(default, null):CoroutinePriority = Processing;
	var lastResult:FrameYield = null;
	var system:CoroutineSystem = CoroutineSystem.MAIN;
	var data: Map<String, Dynamic>;

	var onceCallbacks:Array<Void->Dynamic> = [];
	var onceResults:Array<Dynamic> = [];
	var onceIndex:Int = 0;

	public function getData(key: String): Dynamic {
		if(data == null) return null;
		return data[key];
	}

	public function setData(key: String, value: Dynamic): Void {
		if(data == null) data = [];
		data[key] = value;
	}

	private inline function get_dt():Float {
		return Timer.dt;
	}

	private function new(coro:CoroutineBaseFunction<T>) {
		this.coro = coro;
		this.uuid = ludi.commons.UUID.generate();
		this.future = new Future();
	}

	private function invoke():FrameYield<T> {
		onceIndex = 0;
		system.contextStack.push(this);
		var res = coro(this);
		if(res == null) res = Stop;
		system.contextStack.pop();
		lastResult = res;
		isWaiting = false;

		switch res {
			case WaitNextFrame:
				isWaiting = true;
			case WaitFrames(f):
				framesToWait = f;
				isWaiting = true;
			case WaitSeconds(s):
				timeToWait = s;
				isWaiting = true;
			case Suspend(future):
				isWaiting = true;
				future.then((value) -> {
					result = value;
					isComplete = true;
					isWaiting = false;
				});
			case Return(v):
				result = v;
				isComplete = true;
				system.routinesToRemoveThisFrame.push(uuid);
				system.routinesToNotifyThisFrame.push(this);
			case Stop:
				isComplete = true;
				system.routinesToRemoveThisFrame.push(uuid);
				system.routinesToNotifyThisFrame.push(this);
		}
		return res;
	}

	private function once(callback:MaybeReturn<T>):T {
		var idx = onceIndex;
		onceIndex++;
		if (idx < onceResults.length) {
			return cast onceResults[idx];
		}
		

		var res:T = (callback : Void->T)();
		onceCallbacks.push(callback);
		onceResults.push(res);
		return res;
	}
}

@:using(heaps.coroutine.macros.FrameYieldMacroExtensions)
enum FrameYield<T = Dynamic> {
	WaitNextFrame;
	WaitFrames(f:Int);
	WaitSeconds(f:Float);
	Stop;
	Return(value:T);
	Suspend(future:Future);
}

enum abstract CoroutinePriority(Int) from Int to Int {
	var Controls = 0;
	var Processing = 1;
	var Rendering = 2;
}

@:access(heaps.coroutine.CoroutineSystem)
@:access(heaps.coroutine.CoroutineContext)
class CoroUtils {
	public static function isComplete(coro:Coroutine):Bool {
		return coro.context().isComplete;
	}

	public static function getResult<T>(coro:Coroutine<T>):T {
		return coro.context().result;
	}

	public static function getFuture<T>(coro:Coroutine<T>):Future<T> {
		return coro.context().future;
	}

	public static function hasNextOnce(coro:Coroutine = null):Bool {
		if (coro == null) {
			var ctx = heaps.coroutine.CoroutineSystem.MAIN.contextStack.peek();
			if (ctx == null) return false;
			return ctx.onceIndex < ctx.onceResults.length;
		}
		return coro.context().onceIndex < coro.context().onceResults.length;
	}

	public static function incrementOnce(coro:Coroutine = null):Void {
		if (coro == null) {
			var ctx = heaps.coroutine.CoroutineSystem.MAIN.contextStack.peek();
			if (ctx != null) ctx.onceIndex++;
			return;
		}
		coro.context().onceIndex++;
	}
}
