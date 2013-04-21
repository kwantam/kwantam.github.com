% Uncurrying Functions For Mad(wo)men
% Riad Wahby
% 2013 Apr 21

What if we wanted to take a function of several arguments and turn it
into an equivalent function that takes a single list containing the
arguments?

Before we begin, I am 100% aware that no sane person would ever really
do this; let's just see what kind of stupid tricks we can do with
Template Haskell and the type system.

At first you might be tempted to do this in a straightforward way
by folding:

< add5 a b c d e = a + b + c + d + e
< listApply    []  fn = fn
< listApply (l:ls) fn = listApply ls $ fn l

But surely this can't possibly typecheck: `add5` has type

< add5 :: Num a => a -> a -> a -> a -> a -> a

but as soon as we apply one argument to it, the type becomes

< add4 :: Num a => a -> a -> a -> a -> a

We have a couple of options: we can do this rather easily with Template
Haskell, or we can have a little more fun and create a recursive type in
order to make `listApply` typecheck.

Template Haskell
--

(Note: this file is Literate Haskell. You can grab the <a
href="http://github.jfet.org/lhs/ListApply.lhs">raw version</a>, dump it
into GHCI, and play along at home. Don't forget the `-XTemplateHaskell`
argument.)

> {-# LANGUAGE TemplateHaskell #-}
> module ListApply where
> import Language.Haskell.TH
> import Language.Haskell.TH.Syntax

First, if we want to play with functions that take arguments of type
`Double`, we'll need an instance for the Lift typeclass:

> instance Lift Double where
>     lift x = return $ LitE (RationalL (toRational x))

Now then, we can just splice up a syntax tree corresponding to what we
really wanted to do above with `listApply`:

> lApplyTH'    []  fn = return $ VarE (mkName fn)
> lApplyTH' (l:ls) fn = [| $(lApplyTH' ls fn) l |]
>
> lApplyTH ls = lApplyTH' $ reverse ls

Then we can splice in a list call somewhere in our code:

< $(lApplyTH ([2,3]::[Double]) "**")

Of course, this is annoying in a few ways: the stage restriction
prevents us from using this code in the same module as the definition of
`lApplyTH`, and we have to use the name of the function rather than the
function itself when constructing the AST.

Isorecursive Datatype
--

We can also accomplish our goal (in a slightly more interesting way,
no less) using an isorecursive datatype while avoiding Template
Haskell entirely.

Returning to the original `listApply` definition above, what if we made
a datatype that would encapsulate the fact that we're applying an
argument such that upon applying an argument, we get back a value of the
same type?

The base case is easy: 

> data RecT a = RecR a

We roll up a bare value inside the base case constructor `RecR`,
and upon unrolling it we get something out of type `a`. What about
the recursive call?

>             | RecCR (a -> RecT a)

Here, we roll up an application of type `a` to a `RecT`, generating
another `RecT`.

Note that the structure of this datatype is extremely similar to the
structure of the list datatype. In effect, we're morphing our function
into a list-like object.

To actually create a `RecT`, we might say

< rolled1Value = RecR (1 :: Integer)

This is an integer wrapped up into a `RecT Integer`. More generally:

> lift0RecT = RecR
> rolled1Value = lift0RecT 1

Let's go one step further: what if we want to roll up a function
of one argument?

> lift1RecT fn = RecCR $ \a -> lift0RecT $ fn a

This is slightly tricky. If we already had the argument for our
function, we could make a `RecT` by lifting the result of the function
application to the argument with `RecR`. Thus, we assume that we have
the argument by wrapping the lift inside a lambda, then make a `RecT` by
wrapping the lambda inside a `RecCR`.

We can do this for a function of two arguments by extending our lifting
function in the same way, and so on and so forth:

> lift2RecT fn = RecCR $ \a -> lift1RecT $ fn a
> lift3RecT fn = RecCR $ \a -> lift2RecT $ fn a
> lift4RecT fn = RecCR $ \a -> lift3RecT $ fn a
> lift5RecT fn = RecCR $ \a -> lift4RecT $ fn a
> lift6RecT fn = RecCR $ \a -> lift5RecT $ fn a

OK, we can roll stuff up, but how the heck do we unroll it? Pattern
matching, naturally:

> unrollRecT (RecR val) = val
> unrollRecT _          = undefined
>
> reduceRecT (RecCR fn) = fn
> reduceRecT _          = undefined

You might ask what the hell we're doing with two separate functions
here. The answer is that we're avoiding the occurs check! We haven't
completely hidden our crazy ways inside `RecT`, and we still need to be
up-front with the type system about whether we expect a value (`RecR`)
or a function application (`RecCR`). Put another way: `val` and `fn`
don't have the same type, so `unrollRecT` and `reduceRecT` can't be
collapsed into one function.

To apply a list, we just have to go on an unrolling spree:

> lApply    []  fn = unrollRecT fn
> lApply (l:ls) fn = lApply ls $ (reduceRecT fn) l

(Note that we don't have to reverse the list order this time, since we
reversed it once when rolling up the function and then again when
unrolling it.)

Now then, if we define

> powRecT = lift2RecT (**)

then we could say

< lApply [2,3] powRecT

Sadly, the way we've defined `lApply` precludes partial application.
However, we could allow partial applications by leaving off the
final unroll:

> lApplyPart    []  fn = fn
> lApplyPart (l:ls) fn = lApplyPart ls $ (reduceRecT fn) l

In that case, we'd have to manually unroll it ourselves, or just use
`lApply` on the final application:

< lApply [3] $ lApplyPart [2] powRecT

The other thing that might be useful is actually making a function that
takes a list directly, rather than one that has to be evaluated with
`lApply`. Trivially,

> listPow = flip lApply powRecT
> listPowPart = flip lApplyPart powRecT

For the second one, we always have to remember to unroll it ourselves
once we've applied enough values:

< lApply [3] (listPowPart [2])

Conclusions
--

Compared to something like scheme where no one would bat an eyelash at
recursively applying values from a list to a curried function, the
Haskell type system clearly demands a bit more formality. As I noted
above, this example is pretty limited in its usefulness; nevertheless,
it's an interesting little thought experiment, and of course
isorecursive datatypes are hugely useful (lists, anyone?).

If you haven't yet, you might read through a discussion on expressing
the <a href="http://blog.jfet.org/2009/06/14#2009061401">Y-combinator in
a Hindley-Milner type system</a>. You'll likely find the material very
familiar once you've read the above.
