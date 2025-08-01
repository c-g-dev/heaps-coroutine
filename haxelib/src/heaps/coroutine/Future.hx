package heaps.coroutine;

@:using(heaps.coroutine.macros.FutureMacroExtensions)
class Future<T = Dynamic> {
	public var isComplete(default, null):Bool;

	private var _result:T;
	private var callbacks:Array<T->Void> = [];

	public function new() {
		isComplete = false;
	}

	public static function of<T>(value:T):Future<T> {
		var future = new Future<T>();
		future.resolve(value);
		return future;
	}

	public function then(cb:T->Void):Void {
		if (isComplete)
			cb(_result);
		else
			callbacks.push(cb);
	}

	public function map<U>(cb:T->U):Future<U> {
		var future = new Future<U>();
		then((value) -> future.resolve(cb(value)));
		return future;
	}

	public function resolve(value:T):Void {
		if (isComplete)
			return;
		_result = value;
		isComplete = true;
		for (cb in callbacks)
			cb(value);
		callbacks = [];
	}

	public static function all(futures:Array<Future>):Future<Array<Dynamic>> {
		var future = new Future<Array<Dynamic>>();
		var results:Array<Dynamic> = [];
		var count = futures.length;
		for (eachFuture in futures) {
			eachFuture.then((value) -> {
				results.push(value);
				count--;
				if (count == 0) {
					future.resolve(results);
				}
			});
		}
		return future;
	}

	public static function race(futures:Array<Future>):Future<Dynamic> {
		var future = new Future<Dynamic>();
		for (eachFuture in futures) {
			eachFuture.then((value) -> future.resolve(value));
		}
		return future;
	}
	
	public static function immediate(): Future {
		var f = new Future();
		f.isComplete = true;
		return f;
	}
}