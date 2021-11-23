# Behaviour of namespace histories during a merge.

Note: This is a descriptive test meant to capture the current behaviour of 
branch histories during a merge.
It isn't prescriptive about how merges _should_ work with respect to child branches, 
but I think we should at least notice if we change things by accident.


## Setting up some history

```ucm:hide
.> builtins.merge
```

```unison
parent.top = "top"
parent.child.thing = "parent.child.thing"
```

The child branch has a single history node representing the addition of `parent.child.thing`.

```ucm
.> add
.> history parent.child
```

If we add another thing to the child namespace it should add another history node.

```unison
parent.child.thing2 = "parent.child.thing2"
```


```ucm
.> add
.> history parent.child
```

## Forking off some history on a separate branch

Now we fork the parent namespace to make some changes.

```ucm
.> fork parent parent_fork
```

```unison
parent_fork.child.thing3 = "parent_fork.child.thing3"
```

```ucm
.> add
.> history parent_fork.child
```

## Saving our parent state

```ucm
.> fork parent parent_squash_base
.> fork parent parent_merge_base
```

## Squash merge

Now, if I squash-merge back into parent, we expect `parent_fork.child.thing3` to be added.

```ucm
.> merge.squash parent_fork parent_squash_base
.> history parent_squash_base
```

Notice that with the current behaviour, the history of `parent.child` is completely wiped out, containing nothing from the source OR destination.
This doesn't seem desirable.

```ucm
.> history parent.child
.> history parent_fork.child
.> history parent_squash_base.child
```

## Standard merge

Now, if I merge back into parent, we expect `parent_fork.child.thing3` to be added.

```ucm
.> merge parent_fork parent_merge_base
.> history parent_merge_base
```

Notice that with the current behaviour, the history of `parent.child` is completely wiped out, containing nothing from the source OR destination.
This doesn't seem desirable.

```ucm
.> history parent.child
.> history parent_fork.child
.> history parent_merge_base.child
```
