package heaps.coroutine.macros;

import haxe.macro.Expr;
import heaps.coroutine.Coroutine.FrameYield;

class FrameYieldMacroExtensions {

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