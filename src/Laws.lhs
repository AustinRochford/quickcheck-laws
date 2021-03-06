Recently, I was somewhat idly thinking about how to verify that Haskell typeclasses satisfy the appropriate laws.  My first thought was to use equational reasoning to prove that the laws hold.  For example, to verify that the left identity law holds for the `Maybe` monad, we can show that

```haskell
return x >>= f = Just x >>= f = f x
```

While this proof is simple (due to the simplicity of the `Maybe` monad), I wanted a solution expressed in executable Haskell that could be included in a test suite.  As with many Haskell testing problems, [`QuickCheck`](http://hackage.haskell.org/package/QuickCheck) seemed to be a natural solution.  In this post, I'll show how to verify typeclass laws using `QuickCheck` for the classes `Monoid`, `Functor`, and `Monad`.

The definition of the `Monoid` typeclass is

```haskell
class Monoid a where
  mappend :: a -> a -> a
  mempty :: a
```

The module [`Data.Monoid`](http://hackage.haskell.org/package/base-4.7.0.0/docs/Data-Monoid.html) defines the infix operator `(<>)` as a synonym for `mappend`.  We will use the more consise operator form here.

An instance of `Monoid` must satisy the associative law

```haskell
x <> (y <> z) == (x <> y) <> z
```

and the identity laws

```haskell
x <> mempty == x
```

and

```haskell
mempty <> x == x
```

We begin by writing a proposition to test the assocative law, which is fairly straightforward.

\begin{code}
{-# LANGUAGE ViewPatterns #-}

module Laws where

import Control.Applicative ((<$>))

import Data.Monoid

import Test.QuickCheck
import Test.QuickCheck.Function
import Test.QuickCheck.Gen

monoidAssocProp :: (Eq m, Monoid m) => m -> m -> m -> Bool
monoidAssocProp x y z = (x <> (y <> z)) == ((x <> y) <> z)
\end{code}

We can use this code to test the `Monoid` instance of `[Int]` as follows.

```haskell
quickCheck (monoidAssocProp :: [Int] -> [Int] -> [Int] -> Bool)
+++ OK, passed 100 tests.
```

It is important to include the type annotation, as `monoidAssocProp` is written to be applicable to any monoid (technically any monoid that is also an instance of `Eq`, but this restriction is not too onerous).

Similarly, we can test the right and left identity laws as follows.

\begin{code}
monoidRightIdProp :: (Eq m, Monoid m) => m -> Bool
monoidRightIdProp x = x == (x <> mempty)

monoidLeftIdProp :: (Eq m, Monoid m) => m -> Bool
monoidLeftIdProp x = (mempty <> x) == x
\end{code}

```haskell
quickCheck (monoidRightIdProp :: [Int] -> Bool)
+++ OK, passed 100 tests.

quickCheck (monoidLeftIdProp :: [Int] -> Bool)
+++ OK, passed 100 tests.
```

At this point, we can feel reasonable sure that the `Monoid` instance of `[Int]` satisfies the monoid laws.  `QuickCheck` supports testing many monoids out-of-the-box in this manner, but others require more work on our part.

Suppose we would like to check the monoid laws for `Sum Int`.  (Recall that `mappend` for `Sum Int` is addition and `mempty` is zero.)

```haskell
quickCheck (monoidRightIdProp :: Sum Int -> Bool)
```

Unfortunately, this command fails with the following message.

```
No instance for (Arbitrary (Sum Int))
  arising from a use of `quickCheck'
Possible fix: add an instance declaration for (Arbitrary (Sum Int))
In the expression:
  quickCheck (monoidRightIdProp :: Sum Int -> Bool)
In an equation for `it':
    it = quickCheck (monoidRightIdProp :: Sum Int -> Bool)
```

In order to generate test cases, `QuickCheck` requires the arguments of our proposition to be instances of the `Arbitrary` class.  Fortunately, since `Int` is an instance of `Arbitrary`, we can quickly make `Sum Int` an instance of arbitrary as well.  In fact, for any data type `a` which is an instance of `Arbitrary`, we will make `Sum a` an instance of `Arbitrary` as well.

\begin{code}
instance (Arbitrary a) => Arbitrary (Sum a) where
    arbitrary = Sum <$> arbitrary
\end{code}

Now we can verify the monoid laws for `Sum Int`.

```haskell
quickCheck (monoidAssocProp :: Sum Int -> Sum Int -> Sum Int -> Bool)
+++ OK, passed 100 tests.

quickCheck (monoidRightIdProp :: Sum Int -> Bool)
+++ OK, passed 100 tests.

quickCheck (monoidLeftIdProp :: Sum Int -> Bool)
+++ OK, passed 100 tests.
```

Even considering the need to define `Arbitrary` instances for some `Monoid`s, testing the monoid laws was fairly straightforward.  Testing the functor laws with `QuickCheck` is a bit more involved, due to the need to generate random functions between `Arbitrary` instances.

The definition of the `Functor` typeclass is

```haskell
class Functor f where
    fmap :: (a -> b) -> f a -> f b
```

An instance of `Functor` must satisfy the identity law

```haskell
fmap id = id
```

and the composition law

```haskell
fmap (f . g) = fmap f . fmap g
```

Testing the identity law is relatively simple, since it does not involve arbitrary functions.

\begin{code}
functorIdProp :: (Functor f, Eq (f a)) => f a -> Bool
functorIdProp x = (fmap id x) == x
\end{code}

We can test the identity law for the `Maybe` functor applied to `String`s.

```haskell
quickCheck (functorIdProp :: Maybe String -> Bool)
+++ OK, passed 100 tests.
```

Testing the composition law is a bit more complicated, as `f :: a -> b` and `g :: b -> c` may be arbitrary functions.  Fortunately, [`Test.QuickCheck.Function`](http://hackage.haskell.org/package/QuickCheck-2.7.3/docs/Test-QuickCheck-Function.html) provides a way to generate arbitrary functions `a -> b` (as long as `a` and `b` are instances of appropriate typeclasses).  The `Fun` data type from this module represents an arbitrary function.  With this module, we can write a proposition testing the composition law as follows.

\begin{code}
functorCompProp :: (Functor f, Eq (f c)) => f a -> Fun a b -> Fun b c -> Bool
functorCompProp x (apply -> f) (apply -> g) = (fmap (g . f) x) == (fmap g . fmap f $ x)
\end{code}

Here we use a [view pattern](https://www.fpcomplete.com/school/to-infinity-and-beyond/pick-of-the-week/guide-to-ghc-extensions/pattern-and-guard-extensions#viewpatterns) to extract a function `a -> b` from the second argument, which has type `Fun a b`, using the `apply` function.  We similarly use a view pattern to extract a function `b -> c` from the third argument.

We can use this function to test the composition law for the list functor applied to `Int` with two functions `Int -> Int` as follows

```haskell
quickCheck (functorCompProp :: [Int] -> Fun Int Int -> Fun Int Int -> Bool)
+++ OK, passed 100 tests.
```

The test `functorCompProp` is rather flexible.  We can test the `Functor` instance of `Maybe`, staring with `Int` and involving arbitrary functions `Int -> String` and `String -> Double` as follows.

```haskell
quickCheck (functorCompProp :: Maybe Int -> Fun Int String -> Fun String Double -> Bool)
+++ OK, passed 100 tests.
```

For certain types, this test may take a while to run, as generating arbitrary functions can take some time for the right (or wrong, depending on your point of view) combination of domain and range types.

As with functors, testing the monad laws relies heavily on the `Arbitrary` instance of `Fun`, with slightly more complicated types.

The definition of the `Monad` typeclass is

```haskell
class Monad m where
    (>>=) :: m a -> (a -> m b) -> m b
    return :: a -> m a
```

An instance of `Monad` must satisfy three laws.  The first is the right identity law,

```haskell
x >>= return = x
```

The second is the left identity law,

```haskell
return x >>= f = f x
```

The third is the associative law,

```haskell
(x >>= f) >>= g = x >>= (\x' -> f x' >>= g)
```

Testing the right identity law is fairly straightforward, because it involves no arbitrary functions.

\begin{code}
monadRightIdProp :: (Monad m, Eq (m a)) => m a -> Bool
monadRightIdProp x = (x >>= return) == x
\end{code}

We can test the right identity law for the type `Either String Int` (recall that `Either a` is a monad) as follows

```haskell
quickCheck (monadRightIdProp :: Either String Int -> Bool)
+++ OK, passed 100 tests.
```

Since the left identity law only involves one arbitrary function, it is slightly simpler to test than the associative law.

\begin{code}
monadLeftIdProp :: (Monad m, Eq (m b)) => a -> Fun a (m b) -> Bool
monadLeftIdProp x (apply -> f) = (return x >>= f) == (f x)
\end{code}

We can verify the left identity law for `[Int]` as follows.

```haskell
quickCheck (monadLeftIdProp :: Int -> Fun Int [Int] -> Bool)
+++ OK, passed 100 tests.
```

Finally, we write a test for the associative property.

\begin{code}
monadAssocProp :: (Monad m, Eq (m c)) => m a -> Fun a (m b) -> Fun b (m c) -> Bool
monadAssocProp x (apply -> f) (apply -> g) = ((x >>= f) >>= g) == (x >>= (\x' -> f x' >>= g))
\end{code}

We can verify the associative law for the `Maybe` monad and functions `f :: Int -> Maybe [Int]` and `g :: [Int] -> Maybe String` as follows.

```haskell
quickCheck (monadAssocProp :: Maybe Int -> Fun Int (Maybe [Int]) -> Fun [Int] (Maybe String) -> Bool)
+++ OK, passed 100 tests.
```
