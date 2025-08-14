package heaps.coroutine.macros;

import haxe.macro.Expr;
import haxe.macro.Context;
import heaps.coroutine.Coroutine.CoroutineContext;

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

	public static macro function store<T>(ctxExpr:ExprOf<CoroutineContext<T>>, variable:Expr):Expr {
		var name = switch (variable.expr) {
			case EConst(CIdent(n)): n;
			default: Context.error("ctx.store expects an identifier", variable.pos);
		};
		return macro $ctxExpr.setData($v{"__" + name}, $variable);
	}

	public static macro function unstore<T>(ctxExpr:ExprOf<CoroutineContext<T>>, variable:Expr):Expr {
		var name = switch (variable.expr) {
			case EConst(CIdent(n)): n;
			default: Context.error("ctx.unstore expects an identifier", variable.pos);
		};
		var pos = variable.pos;
		var getExpr:Expr = macro $ctxExpr.getData($v{"__" + name});
		var declareExpr:Expr = {
			expr: EVars([
				{name: name, type: null, expr: getExpr}
			]),
			pos: pos
		};
		return { expr: EBlock([declareExpr]), pos: pos };
	}
}
