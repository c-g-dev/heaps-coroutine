package heaps.coroutine;

import heaps.coroutine.ds.MaybeReturn;
import heaps.coroutine.Coroutine.CoroutineContext;
import heaps.coroutine.CoroutineSystem;
import heaps.coroutine.Coroutine.CoroutineFunction;
import heaps.coroutine.ext.CoroutineExtensions;
import heaps.coroutine.Coroutine.FrameYield;


import haxe.macro.Expr;
//import haxe.macro.ExprOf;


@:access(heaps.coroutine.CoroutineSystem)
@:access(heaps.coroutine.CoroutineContext)
class Coro {
    public static function start(coroutine: CoroutineFunction):Coroutine {
        var coro = new Coroutine(coroutine);
        CoroutineExtensions.start(coro);
        return coro;
    }

    public static function defer(coroutine: CoroutineFunction):Coroutine {
        var coro = new Coroutine(coroutine);
        return coro;
    }

    public static function once<T>(callback: MaybeReturn<T>):T {
        var ctx = CoroutineSystem.MAIN.contextStack.peek();
        if (ctx == null) {
            return (callback : Void -> T)();
        }

        return ctx.once(callback);
    }

    public static macro function yield(callingExpr:ExprOf<FrameYield>):Expr {
        return macro {
            if(!heaps.coroutine.CoroUtils.hasNextOnce()){
                return heaps.coroutine.Coro.once(() -> return $callingExpr);
            }
            else {
                heaps.coroutine.CoroUtils.incrementOnce();
            }
        }
    }

}