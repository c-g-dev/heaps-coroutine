package heaps.coroutine.macros;

import heaps.coroutine.Future;
import haxe.macro.Expr;
import haxe.macro.Context;

class FutureMacroExtensions {


	public static macro function await<T>(callingExpr:ExprOf<Future<T>>):Expr {
		var expected = Context.getExpectedType();
		var valueNeeded = switch (expected) {
			case null: false;
			default: true;
		};

		if (!valueNeeded) {
			return macro {
				var __future = heaps.coroutine.Coro.once(() -> {return $callingExpr;});
				if (!__future.isComplete)
					return heaps.coroutine.Coroutine.FrameYield.Suspend(__future);
			};
		} else {
			return macro {
				var __future = heaps.coroutine.Coro.once(() -> return $callingExpr);

				var __awaitResult:Dynamic = null;

				if (!__future.isComplete) {
					return heaps.coroutine.Coroutine.FrameYield.Suspend(__future);
				} else {
					@:privateAccess __awaitResult = __future._result;
				}

				__awaitResult;
			};
		}
	}
}
