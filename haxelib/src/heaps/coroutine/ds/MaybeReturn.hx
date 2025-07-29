package heaps.coroutine.ds;

abstract MaybeReturn<T>(Void->T) to Void->T from Void->T {
	public inline function new(callback:Void->T) {
		this = callback;
	}

	@:from
	public static inline function fromVoid2Void(callback:Void->Void):MaybeReturn<Dynamic> {
		return new MaybeReturn(() -> {
			callback();
			return null;
		});
	}
}
