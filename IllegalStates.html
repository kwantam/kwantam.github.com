---
published: true
---
{% highlight lhs %}
Efficiently Detecting Illegal States in Twisted-Ring FSM State Vectors
==

Let's meditate on the nature of FSMs utilizing twisted-ring state
vectors. Such FSMs have some nice properties: a more efficient state
coding than a one-hot machine, gray state transitions, and a trivial
computation of the next state vector.

However, since not all state bit vectors represent legal states, most
designers will want to include illegal state detection. While not as
onerous as illegal state detection in a one-hot machine, at first blush
it seems that illegal state detection could be far worse than in a FSM
using compact state coding.

Let's see if we can't do a little better. First, some setup.

(Note: this file is Literate Haskell. You can grab the raw version, dump
it into GHCI, and play along at home!)

> module IllegalStates where
> import Data.List ((\\), findIndices, nubBy)

We're talking about logic, but `Bool`s are visually noisy. Let's just
agree to behave ourselves and operate on lists containing 0 and 1 to
make for less typing and easier reading.

> inv 1 = 0
> inv 0 = 1
> inv _ = undefined

Generating Twisted Rings
--

The twisted ring transition is simple: shift all the bits left, and
insert the inverse of the MSB into the LSB. (See also:
http://en.wikipedia.org/wiki/Ring_counter )

> tRingNext    []  = []
> tRingNext (b:bs) = bs ++ [inv b]

`iterate` takes a function and an initial argument and creates an
infinite list of applications of the function to the previous value of
the list, with the initial argument itself as the base case. Using this,
we can make a function that returns a (possibly) finite list by ending
when we see the initial argument again.

> iterateUniq f x = x : takeWhile (\y -> x /= y) xs
>     where (_:xs) = iterate f x

Applying this operation to the twisted ring transition gives us a
function that returns a list of all states of a twisted ring counter
starting at some initial state.

> tRing = iterateUniq tRingNext

We're treating lists of `{0,1}` as bit vectors; we'll want a way to
generate all possible bit vectors of a given length:

> bitStrings 0 = [[]]
> bitStrings n = ( map (0:) nm1 ) ++ ( map (1:) nm1 )
>   where nm1 = bitStrings $ n - 1
> allStates5 = bitStrings 5

Legal States
--

Legal states in a twisted ring are those in the ring containing
all zeros. For example, in a 5-bit ring:

    00000
    00001
    00011
    00111
    01111
    11111
    11110
    11100
    11000
    10000

Note that these rings have an interesting property: there is at most one
sequential pair of dissimilar bits. Further, we can uniquely identify
all ten states by looking at only two bits. In the case of the states
that are all 0 or all 1, we look at the first and last bits, because we
know that if they're the same all the ones between must be as well. In
the other states, we look for the 01 or 10 transition, whose position is
unique among the states.

Thus, we could write a set of ten functions each of which selects one of
the legal states. These might look like

> inState0 [0,_,_,_,0] = True ; inState0 _ = False
> inState1 [_,_,_,0,1] = True ; inState1 _ = False
> inState2 [_,_,0,1,_] = True ; inState2 _ = False
> inState3 [_,0,1,_,_] = True ; inState3 _ = False
> inState4 [0,1,_,_,_] = True ; inState4 _ = False
> inState5 [1,_,_,_,1] = True ; inState5 _ = False
> inState6 [_,_,_,1,0] = True ; inState6 _ = False
> inState7 [_,_,1,0,_] = True ; inState7 _ = False
> inState8 [_,1,0,_,_] = True ; inState8 _ = False
> inState9 [1,0,_,_,_] = True ; inState9 _ = False

But why write functions we can generate instead?

Generating One-Hot Selectors For Legal States
--

Let's consider how we can generate the one-hot bit selectors for the
legal states. Recall from above that these have a specific form: either
every bit in the vector is the same, in which case the first and last
bit in the vector are the same, or the beginning and end of the vector
have opposite sign, and there is one 01 or 10 transition somewhere in
the vector.

Obviously there's nothing to detect in vectors of 0 length:

> oneHotVecs 0 = []

Otherwise, we can easily make the selectors for all-0 or all-1 vectors
and generate a list of selectors for 01 and 10.

`allX` simply matches the first and last elements of a list to some
supplied value, in our case 0 or 1. `selX` generates a list of
functions that match a supplied list against some subsequence of length
two of the argument.

> oneHotVecs n = (allX 0 : selX [0,1] (n-2)) ++ (allX 1 : selX [1,0] (n-2))
>   where allX x ls = (head ls == x) && (last ls == x)
>         selX x m 
>           | m < 0     = []
>           | otherwise = (\ls -> take 2 (drop m ls) == x)
>                         : selX x (m-1)
> inStatesL5 = oneHotVecs 5

`inStatesL5` is now just the list of `inStateX` functions given above.

If we want to apply multiple selectors simultaneously, we might provide
a list of them and apply them all to a given input. Here's one way to do
this in an abrasively point-free style:

> allL fns = and . flip map fns . flip ($)

If we were feeling somewhat less obtuse, we might instead say

    allL fns x = and (map ($x) fns)

Illegal States
--

The illegal states are all bit strings of length N that aren't in the
ring consisting of N zeros.

> illegalStates5 = allStates5 \\ tRing [0,0,0,0,0]

Like the legal states, the illegal states form closed rings: if one
state is in another state's ring, then we can be sure that the two
states produce identical rings modulo a phase shift. This lets us easily
uniqify the list of illegal states into a seed list containing one
(arbitrarily chosen) representative member of each illegal ring.

> sameRing a b = [] /= findIndices (==a) (tRing b)
> illegalState5Seeds = nubBy sameRing illegalStates5

Now we can also segregate all the illegal states into their
respective rings:

> illegalState5Rings = map tRing illegalState5Seeds

One obvious question to ask: how many of the legal state selectors will
an illegal state trigger? Let's apply all the selectors to all the
states to find out.

At this point I think it's clear we have no choice but to escalate our
abuse of `flip` et al:

> nTrigStateSels selL = map $ flip map selL . flip ($)

OK, I admit the golfing is getting a little absurd. We could also just
say

    nTrigStateSels selL states = map (\x -> map ($x) selL) states

Now then, the results of such an application:

> inStateVecs5 = nTrigStateSels inStatesL5 allStates5
> numInStatesByString = zip allStates5 $ map (length . filter id) inStateVecs5

Looking at this list we see that legal states match exactly 1 selector
(as we should expect), while most illegal states match 3 selectors. The
two alternating states, 01010 and 10101, each match 5 selectors!

Canary Combinations
--

Now, the million dollar question: can we pick some subset of the
selectors such that those selectors will all match at least one state in
all of the illegal rings? If we can, then we've found a much less
expensive way of detecting illegal states (though note that we will
likely have to transition through a few illegal states before we get to
one that we detect as such).

Obviously, we'll need to be able to generate n-way combinations so that
we can make a bunch of multi-selectors:

> combinations 0    _   = []
> combinations 1    ls  = map (:[]) ls
> combinations n (l:ls) = cHlp l ls
>   where cHlp l []          = []
>         cHlp l l2@(nl:nl2) = map (l:) (combinations (n-1) l2) ++ cHlp nl nl2

Now we can generate all two-way selector functions. Sadly, there's no
good way of making a `Show` instance for functions; instead, we're going
to make a new "named function" datatype that's showable. (Note, though,
that our `Eq`, `Ord`, and `Show` instances only work on the names, not
on the functions themselves.)

> data NamedFunc n f = NFunc n f
> instance (Show t1) => Show (NamedFunc t1 t2) where
>   show (NFunc n _) = "NF" ++ show n
> instance (Eq t1) => Eq (NamedFunc t1 t2) where
>   (==) (NFunc n1 _) (NFunc n2 _) = n1 == n2
> instance (Ord t1) => Ord (NamedFunc t1 t2) where
>   compare (NFunc n1 _) (NFunc n2 _) = compare n1 n2
> applyNF (NFunc _ f) = f

Using this, 

> twoStateCombFuncs = map allL $ combinations 2 inStatesL5
> twoStateCombNames = map (\(x:y:[]) -> (x,y)) $ combinations 2 [0,1,2,3,4,5,6,7,8,9]
> twoStateCombs = zipWith NFunc twoStateCombNames twoStateCombFuncs

Now `twoStateCombs` is a vector of `NamedFunc` that we can apply to every
state in the illegal rings. We are looking for a `NamedFunc` that matches
at least one state in all illegal rings.

> canaryCombos5 = filter isTrue $ map tryComb twoStateCombs
>   where tryComb nf = (nf,and $ flip map illegalState5Rings
>                              $ or . map (applyNF nf))
>         isTrue (_,b) = b

For each canary combination, we might be interested in knowing how many
total states they match; a canary that matches more states will, on
average, detect that we're in an illegal state more quickly.

> canaryMatches5 = map nMatches canaryCombos5
>   where nMatches (nf,_) = (nf, length . concat $ 
>                                ( map . filter $ applyNF nf ) illegalState5Rings)

Sadly, at least in the case of 5-bit rings, all of them match exactly 4 states.

Now that we've worked through the whole process by hand for 5-bit rings,
let's put it all together into a function that dumps out all the canary
combinations for a ring of some specified length.

> canaryCombos n = filter isTrue $ map tryComb twoSelNFs
>   where isTrue (_,b) = b
>         tryComb nf = (nf,and $ flip map illRings $ or . map (applyNF nf))
>         illStates = (bitStrings n) \\ (tRing . take n $ repeat 0)
>         illSeeds = nubBy sameRing illStates
>         illRings = map tRing illSeeds
>         twoSelFns = map allL $ combinations 2 $ oneHotVecs n
>         twoSelNms = combinations 2 $ take (2*n) [0..]
>         twoSelNFs = zipWith NFunc twoSelNms twoSelFns

Very interesting! 5-bit rings seem to be special in that a single
two-selector canary is possible. Let's try again, this time ORing some
number of two-selector canaries.

> anyL fns = or . flip map fns . flip ($)
> canaryOrCombos n m = filter isTrue $ map tryComb twoOrSelNFs
>   where isTrue (_,b) = b
>         tryComb nf = (nf,and $ flip map illRings $ or . map (applyNF nf))
>         illStates = bitStrings n \\ (tRing . take n $ repeat 0)
>         illSeeds = nubBy sameRing illStates
>         illRings = map tRing illSeeds
>         twoSelFns = map allL $ combinations 2 $ oneHotVecs n
>         twoSelNms = combinations 2 $ take (2*n) [0..]
>         twoOrSelFns = map anyL $ combinations m twoSelFns
>         twoOrSelNms = combinations m twoSelNms
>         twoOrSelNFs = zipWith NFunc twoOrSelNms twoOrSelFns

Fascinating. 2, 3, 4, and 5-bit rings need a single selector pair; 6, 7,
and 8-bit rings need two selector pairs; 9 and 10-bit rings need 3.
{% endhighlight %}
