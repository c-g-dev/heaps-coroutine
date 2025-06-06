# heaps-coroutine

Portable coroutine system for Heaps. Autowires itself to the system loop, no configuration or boilerplate required.

```
haxelib install heaps-coroutine
```

## Usage

```haxe
// Anywhere, anytime. No need to call some init() or anything. Attaches itself to the frame loop.
StartCoroutine((dt) -> { // Will start executing next frame
    doStuff();
    if (completed()) {
        return Stop; // Unwire itself
    }
    if (pauseFrames()) {
        return WaitFrames(20);
    }
    if (pauseTime()) {
        return WaitSeconds(2);
    }    
    if (dependentOnOtherCoroutine()) {
        return Suspend(uuid); // uuid stored in the CoroutineSystem
    }
    return WaitNextFrame;
});

```

## Notes

The main goal of this library is **portability**. You can write components with this system to handle on-frame execution and share those components across different Heaps projects out-of-the-box. The consuming library won't even know you're using it.

If you want to use your own implementation of the coroutine resolution system, you can override the class `CoroutineSystem` and set `CoroutineSystem.MAIN`.
