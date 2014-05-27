After cloning this repository, install the dependencies with

```
cabal install --only-dependencies
```

If you have a newer version of `cabal`, you may want to do so inside a sandbox.

You can start `ghci` with the `Law.lhs` module loaded with `cabal repl`.  (Again, this requires a new-ish version of `cabal`.)

See the associated blog [post](http://www.austinrochford.com/posts/2014-05-27-quickcheck-laws.html) for how to use the tests.
