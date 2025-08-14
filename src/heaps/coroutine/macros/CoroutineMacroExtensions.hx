package heaps.coroutine.macros;

import haxe.macro.Expr;
import haxe.macro.Context;

class CoroutineMacroExtensions {
	public static macro function await<T>(callingExpr:ExprOf<Coroutine<T>>):Expr {
		var expected = Context.getExpectedType();
		var valueNeeded = switch (expected) {
			case null: false;
			default: true;
		};

		if (!valueNeeded) {
			return macro {
				var __coro = heaps.coroutine.Coro.once(() -> { return $callingExpr;});
				heaps.coroutine.ext.CoroutineExtensions.start(__coro);
				if (!heaps.coroutine.Coroutine.CoroUtils.isComplete(__coro))
					return heaps.coroutine.FrameYield.Suspend(heaps.coroutine.Coroutine.CoroUtils.getFuture(__coro));
			};
		} else {
			return macro {
				var __coro = heaps.coroutine.Coro.once(() -> return $callingExpr);
				heaps.coroutine.ext.CoroutineExtensions.start(__coro);
				var __awaitResult:Dynamic = null;

				if (!heaps.coroutine.Coroutine.CoroUtils.isComplete(__coro)) {
					return heaps.coroutine.FrameYield.Suspend(heaps.coroutine.Coroutine.CoroUtils.getFuture(__coro));
				} else {
					__awaitResult = heaps.coroutine.Coroutine.CoroUtils.getResult(__coro);
				}

				__awaitResult;
			};
		}
	}
}
