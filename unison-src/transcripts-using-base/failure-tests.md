Tests the Failures generated by builtin functions.

There are three places that the builtins build Failures. One is for
builtins that return Either Failure, one is for builtins that use the
Exception ability directly, and the last is code validation. I don't
have an easy way to test the last at the moment, but the other two are
tested here.

```ucm:hide
.> builtins.mergeio
```

```unison
test1 : '{IO, Exception} [Result]
test1 = do
  fromUtf8 0xsee
  [Ok "test1"]

test2 : '{IO, Exception} [Result]
test2 = do
  tryEval '(bug "whoa")
  [Ok "test2"]
```

```ucm
.> add
```

```ucm:error
.> io.test test1
```

```ucm:error
.> io.test test2
```
