# heaps-coroutine

Portable coroutine system for Heaps. Autowires itself to the system loop, no configuration or boilerplate required.

## Features

- No setup, works out of the box
- Self-managed on-frame coroutines
- Macro-driven `await` and `yield` with no obscure metadata requirements
- Futures
- Extensible and customizable

## Installation

```
haxelib install heaps-coroutine
```

No need to wire to `update()` or include any init macros. When you start a coroutine, it sets up the system loop automatically.

## Examples

### Fade In

```haxe
Coro.start(function (ctx) {
    sprite.alpha += 0.1 * ctx.dt;
    if(sprite.alpha >= 1) {
        return Stop;
    }
    return WaitNextFrame;
});
```

### Run Cutscene

```haxe
Coro.start( (c) -> {
    fadeFromBlack(1).await();

    new Parallel([
        moveChar(hero,  { x : 600, y : 360 }, 3),
        cameraPanTo(    { x : 640, y : 360 }, 3)
    ]).await();

    showDialogue("Hero", "What a beautiful throne room …").await();

    moveChar(king, { x : 580, y : 360 }, 1.5).await();

    showDialogue("King",  "Welcome to my kingdom, brave traveler.").await();
    showDialogue("Hero",  "Your Majesty, I have come as requested.").await();
    showDialogue("King",  "Then let us discuss our plan.").await();

    fadeToBlack(1).await();
    return Stop;
});
```

---

## Overview

```haxe
Coro.start((ctx) -> { // CoroutineContext -> FrameYield
    //run this block every frame

    doStuffOnFrame();

    //return an option from FrameYield enum
    return WaitNextFrame; //executes this function again next frame
    return WaitFrames(f:Int); //suspends this coroutine for f frames
    return WaitSeconds(s:Float); //suspends this coroutine for s seconds
    return Stop; //stops coroutine and deallocates it from the system
    return Return(value:T); //stops coroutine and returns a value, retrievable from coroutine.future().
    return Suspend(future:Future); //suspends this coroutine until the passed in future resovles

    //await functionality, macro funcrion to suspend here until otherCoroutine finishes
    //read below for more info
    otherCoroutine.await(); 

    Coro.once(() -> { doSomethingOnce(); }); //executes code once
    var cachedResult = Coro.once(() -> { return doCalculation(); }); //executes code once and caches result

    //yield functionality, macro function to return this result only one time
    //read below for more info
    WaitNextFrame.yield(); 
    Coro.yield({ //yield entire exection only one time
        doSomeStuff(); 
        WaitNextFrame;
    });
});
```

Pass into `Coro.start()` a function of any of the following:

- `CoroutineContext -> FrameYield`
- `Float (delta time) -> FrameYield`
- `Void -> FrameYield`

---

## Once

`Coro.once()` ensures that a block of code inside a coroutine executes only once.

```haxe
Coro.start((ctx) -> { 
    Coro.once(() -> {trace("first frame");});
    trace("every frame");
    if(ctx.frameCount > 1) {
        Coro.start((_) -> {
            Coro.once(() -> {trace("first frame sunroutine");}); //onces are correctly scoped only to the coroutines in which they are called
            return WaitNextFrame;
        }
    }
    return WaitNextFrame;
});

//Output:
    //first frame (frame 0)
    //every frame (frame 0)
    //every frame (frame 1)
    //every frame (frame 2)
    //first frame sunroutine (frame 2)
    //every frame (frame 3)
    //every frame (frame 4)
    //every frame (every subsequent frame until coroutine is stopped)
```

`Coro.once()` works at every level of nesting as long as it is called inside a coroutine. Because all coroutine executions are handled by a centralized system, we are always able to track which coroutine is currently being executed by maintaining a stack which pushes before entering the coroutine and popping on exit. See `CoroutineSystem.hx` for more details.

You can also achieve similar results by gating on 

---

## Await

`Coroutine.await();` is a macro function which converts the code like this:

```haxe
var waitForMe = Coro.defer((ctx) -> {...}); 

//calling await
Coro.start((ctx) -> { 
    sprite.x += 5 * ctx.dt;
    waitForMe.await();
    return Stop;
});

//macro converts to
Coro.start((ctx) -> { 
    sprite.x += 5 * ctx.dt;

    var __coro = heaps.coroutine.Coro.once(() -> return waitForMe;); //wrap coroutine in a once() so that you can use "new Coroutine()" without reinstantiating
    ___coro.start(); //start if doesn't exist
    if (!CoroUtils.isComplete(__coro)) {
        return Suspend(__coro.future());
    }
        
    return Stop;
});
```

**Note, and this is important:**

Even when `waitForMe` finishes, we resume by re-executing the coroutine function from the beginning. So `sprite.x += 5 * ctx.dt;` still executes again. i.e. while we suspend at the `await()` and never execute it again, we do not resume at that line.

If you want to skip the blocks above the await, you can use `Coro.once()` or similar:

```haxe
//calling await
Coro.start((ctx) -> { 
    //never re-enter
    Coro.once(() -> {sprite.x += 5 * ctx.dt;});  
    //OR 
    Coro.yield({
        sprite.x += 5 * ctx.dt;
        WaitNextFrame;
    });
    waitForMe.await();
    return Stop;
});
```

```haxe
//calling await with assignment
Coro.start((ctx) -> { 
    sprite.x += 5 * ctx.dt;
    var myResult = waitForMe.await();
    doSomething(myResult);
    return Stop;
});

//macro converts assignment to
Coro.start((ctx) -> { 
    sprite.x += 5 * ctx.dt;

    var myResult = {
        var __coro = heaps.coroutine.Coro.once(() -> return waitForMe;); //wrap coroutine in a once() so that you can use "new Coroutine()" without reinstantiating
        ___coro.start(); //start if doesn't exist
        var __awaitResult:Dynamic = null;
        if (!CoroUtils.isComplete(__coro)) {
            return Suspend(__coro.future());
        }
        else {
            __awaitResult = CoroUtils.getResult(__coro);
        }
        __awaitResult;
    }

    doSomething(myResult);
        
    return Stop;
});
```

---

## Futures

```haxe
var coro = Coro.defer((ctx) -> {...}); //create coroutine but do not start
var fut = coro.future(); //returns a Future for this coroutine
fut.then((_) -> { doSomething(); }); //excute after future resolves
fut.map((_) -> return startNewCoroutine().future();); // returns Future, chain another future to this one

Coro.start((c) -> {
    fut.await(); // awaits a future resolution
    //OR
    var result = fut.await();
    //...
});
```

---

## CoroutineObject

Allows you to define a coroutine that exists as a class. Then you can extend it, pass it around, etc.

```haxe
class FadeIn extends CoroutineObject {
    override function onFrame(ctx:CoroutineContext):FrameYield {
        sprite.alpha += 0.1 * ctx.dt;
        if(sprite.alpha >= 1) {
            return Stop;
        }
        return WaitNextFrame;
    }
}

new FadeIn().start();
```

---

## Parallel and Sequence

```haxe
//create a coroutine
var coro1 = Coro.defer((ctx) -> { trace("coro1"); if(ctx.frameCount >= 3) { return Stop; } return WaitNextFrame; });
var coro2 = Coro.defer((ctx) -> { trace("coro2"); if(ctx.frameCount >= 3) { return Stop; } return WaitNextFrame; });

//run coro1 and coro2 in parallel
new Parallel([
    coro1,
    coro2
]).start();

//result:
    //coro1
    //coro2
    //coro1
    //coro2
    //coro1
    //coro2

//run coro1 and coro2 sequentially
new Sequence([
    coro1,
    coro2
]).start();

//result:
    //coro1
    //coro1
    //coro1
    //coro2
    //coro2
    //coro2
```
