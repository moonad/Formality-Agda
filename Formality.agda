-- :::::::::::::
-- :: Prelude ::
-- :::::::::::::

module Formality where
open import Logic
open import Nat
open import Equality
open import EquationalReasoning

-- ::::::::::::::
-- :: Language ::
-- ::::::::::::::

-- A λ-calculus term. We're keeping types as simple as possible, so we don't
-- keep a Fin index tracking free vars, nor contexts in any form
data Term : Set where
  var : Nat -> Term
  lam : Term -> Term
  app : Term -> Term -> Term

-- Adjusts a renaming function
shift-fn : (Nat -> Nat) -> Nat -> Nat
shift-fn fn zero     = zero
shift-fn fn (succ i) = succ (fn i)

shift-fn-many : Nat -> (Nat -> Nat) -> Nat -> Nat
shift-fn-many n fn = pow shift-fn n fn

-- Renames all free variables with a renaming function, `fn`
shift : (Nat -> Nat) -> Term -> Term
shift fn (var i)       = var (fn i)
shift fn (lam bod)     = lam (shift (shift-fn fn) bod)
shift fn (app fun arg) = app (shift fn fun) (shift fn arg)

-- Adjusts a substitution map
subst-fn : (Nat → Term) → Nat → Term
subst-fn fn zero     = var zero
subst-fn fn (succ i) = shift succ (fn i)

-- Substitutes all free vars on term with a substitution map, `fn`
subst : (Nat -> Term) -> Term -> Term
subst fn (var i)       = fn i
subst fn (lam bod)     = lam (subst (subst-fn fn) bod)
subst fn (app fun arg) = app (subst fn fun) (subst fn arg)

-- Creates a substitution map that replaces only one variable
at : Nat → Term → Nat → Term
at zero     term zero     = term
at zero     term (succ i) = var i
at (succ n) term = subst-fn (at n term)

-- Performs a global reduction of all current redexes
reduce : Term -> Term
reduce (var i)             = var i
reduce (lam bod)           = lam (reduce bod)
reduce (app (var idx) arg)       = app (var idx) (reduce arg)
reduce (app (lam bod) arg) = subst (at 0 (reduce arg)) (reduce bod)
reduce (app (app ffun farg) arg)       = app (reduce (app ffun farg)) (reduce arg)

-- Computes how many times a free variable is used
uses : Term -> Nat -> Nat
uses (var i)       n with same i n
uses (var i)       n | true  = 1
uses (var i)       n | false = 0
uses (lam bod)     n = uses bod (succ n)
uses (app fun arg) n = uses fun n + uses arg n

uses-n-step : {i n : Nat} -> (p : Nat) -> uses (var (p + i)) (p + n) == uses (var i) n
uses-n-step 0 = refl
uses-n-step (succ p) = uses-n-step p

-- Computes the size of a term
size : Term -> Nat
size (var i)       = 0
size (lam bod)     = succ (size bod)
size (app fun arg) = succ (size fun + size arg)

-- This term is affine
data IsAffine : (t : Term) → Set where
  var-affine : ∀ {a} → IsAffine (var a)
  lam-affine : ∀ {bod} → (uses bod 0 <= 1) → IsAffine bod -> IsAffine (lam bod)
  app-affine : ∀ {fun arg} → IsAffine fun → IsAffine arg -> IsAffine (app fun arg)

-- This term is on normal form
data IsNormal : (t : Term) → Set where
  var-normal : ∀ {a} → IsNormal (var a)
  lam-normal : ∀ {bod} → IsNormal bod -> IsNormal (lam bod)
  app-var-normal : ∀ {fidx arg} → IsNormal arg -> IsNormal (app (var fidx) arg)
  app-app-normal : ∀ {ffun farg arg} → IsNormal (app ffun farg) → IsNormal arg -> IsNormal (app (app ffun farg) arg)

-- This term has redexes
data HasRedex : (t : Term) → Set where
  lam-redex : ∀ {bod} → HasRedex bod -> HasRedex (lam bod)
  app-redex : ∀ {fun arg} → Or (HasRedex fun) (HasRedex arg) -> HasRedex (app fun arg)
  found-redex : ∀ {fbod arg} → HasRedex (app (lam fbod) arg)

-- A normal term has no redexes
normal-has-noredex : (t : Term) → IsNormal t → Not (HasRedex t)
normal-has-noredex (lam bod) (lam-normal bod-isnormal) (lam-redex bod-hasredex) = normal-has-noredex bod bod-isnormal bod-hasredex
normal-has-noredex (app (var idx) arg) (app-var-normal arg-isnormal) (app-redex (or1 arg-hasredex)) = normal-has-noredex arg arg-isnormal arg-hasredex
normal-has-noredex (app (app ffun farg) arg) (app-app-normal fun-isnormal _) (app-redex (or0 fun-hasredex)) = normal-has-noredex (app ffun farg) fun-isnormal fun-hasredex
normal-has-noredex (app (app ffun farg) arg) (app-app-normal _ arg-isnormal) (app-redex (or1 arg-hasredex)) = normal-has-noredex arg arg-isnormal arg-hasredex

-- A term that has no redexes is normal
noredex-is-normal : (t : Term) → Not (HasRedex t) → IsNormal t
noredex-is-normal (var idx) noredex = var-normal
noredex-is-normal (lam bod) noredex = lam-normal (noredex-is-normal bod (noredex ∘ lam-redex))
noredex-is-normal (app (var idx) arg) noredex = app-var-normal (noredex-is-normal arg (noredex ∘ (app-redex ∘ or1)))
noredex-is-normal (app (app ffun farg) arg) noredex = app-app-normal (noredex-is-normal (app ffun farg) (noredex ∘ (app-redex ∘ or0))) (noredex-is-normal arg (noredex ∘ (app-redex ∘ or1)))
noredex-is-normal (app (lam bod) arg) noredex = absurd (noredex found-redex)

-- A term is either normal or has a redex
normal-or-hasredex : (t : Term) → Or (IsNormal t) (HasRedex t)
normal-or-hasredex (var idx) = or0 var-normal
normal-or-hasredex (lam bod) = case-or (normal-or-hasredex bod) (or0 ∘ lam-normal) (or1 ∘ lam-redex)
normal-or-hasredex (app (lam bod) arg) = or1 found-redex
normal-or-hasredex (app (var idx) arg) = case-or (normal-or-hasredex arg) (or0 ∘ app-var-normal) (or1 ∘ (app-redex ∘ or1))
normal-or-hasredex (app (app fun arg') arg) =
  case-or (normal-or-hasredex arg)
          (λ x → case-or (normal-or-hasredex (app fun arg'))
                 (λ y → or0 (app-app-normal y x))
                 (λ y → or1 (app-redex (or0 y))))
          (λ x → or1 (app-redex (or1 x)))

-- Computes the number of redexes in a term
redexes : (t : Term) → Nat
redexes (var idx)                 = 0
redexes (lam bod)                 = redexes bod
redexes (app (var fidx)      arg) = redexes arg
redexes (app (lam fbod)      arg) = 1 + (redexes fbod + redexes arg)
redexes (app (app ffun farg) arg) = redexes (app ffun farg) + redexes arg

-- Directed one step reduction relation, `a ~> b` means term `a` reduces to `b` in one step
data _~>_ : Term → Term → Set where
  ~beta : ∀ {t u} → app (lam t) u ~> subst (at 0 u) t
  ~app0 : ∀ {a f0 f1} → f0 ~> f1 → app f0 a ~> app f1 a
  ~app1 : ∀ {f a0 a1} → a0 ~> a1 → app f a0 ~> app f a1
  ~lam0 : ∀ {b0 b1} → b0 ~> b1 → lam b0 ~> lam b1

-- Directed arbitraty step reduction relation, `a ~>> b` means term `a` reduces to `b` in zero or more steps
data _~>>_ : Term → Term → Set where
  ~>>refl  : ∀ {t t'} → t == t' → t ~>> t'
  ~>>trans : ∀ {t t' t''} → t ~>> t'' → t'' ~>> t' → t ~>> t'
  ~>>step  : ∀ {t t'} → t ~> t' → t ~>> t'

data Normalizable : (t : Term) → Set where
  normal-is-normalizable : ∀ {t} → IsNormal t → Normalizable t
  onestep-normalizable : ∀ {t t'} → t ~> t' → Normalizable t' → Normalizable t

manystep-normalizable : ∀ {t t'} → t ~>> t' → Normalizable t' → Normalizable t
manystep-normalizable (~>>refl refl)         norm = norm
manystep-normalizable (~>>step step)         norm = onestep-normalizable step norm
manystep-normalizable (~>>trans part0 part1) norm = manystep-normalizable part0 (manystep-normalizable part1 norm)

~>>cong : ∀ {bod bod'} → (f : Term → Term) → (∀ {t t'} → t ~> t' → f t ~> f t') → bod ~>> bod' → f bod ~>> f bod'
~>>cong f pf (~>>refl eq) = ~>>refl (cong f eq)
~>>cong f pf (~>>trans part0 part1) = ~>>trans (~>>cong f pf part0) (~>>cong f pf part1)
~>>cong f pf (~>>step x) = ~>>step (pf x)

~>>pow : (f : Term → Term) → (∀ {x} → x ~>> f x) → ∀ {x} n → x ~>> pow f n x
~>>pow f pf 0 = ~>>refl refl
~>>pow f pf (succ n) = ~>>trans (~>>pow f pf n) pf

reduce-~>> : ∀ {t} → t ~>> reduce t
reduce-~>> {var idx} = ~>>refl refl
reduce-~>> {lam bod} = ~>>cong lam ~lam0 reduce-~>>
reduce-~>> {app (var idx) arg} = ~>>cong (app (var idx)) ~app1 reduce-~>>
reduce-~>> {app (lam bod) arg} = let
  part0 = ~>>cong (λ x → app x arg) ~app0 reduce-~>>
  part1 = ~>>cong (app (lam (reduce bod))) ~app1 reduce-~>>
  part2 = ~>>step (~beta {reduce bod} {reduce arg})
  in ~>>trans part0 (~>>trans part1 part2)
reduce-~>> {app (app fun arg') arg} = let
  part0 = ~>>cong (app (app fun arg')) ~app1 reduce-~>>
  part1 = ~>>cong (λ x → app x (reduce arg)) ~app0 reduce-~>>
  in ~>>trans part0 part1

-- :::::::::::::::::::::::::
-- :: Theorems and lemmas ::
-- :::::::::::::::::::::::::

shift-0-aux1 : ∀ idx m → shift-fn-many m (0 +_) idx == idx
shift-0-aux1 idx 0 = refl
shift-0-aux1 0 (succ m) = refl
shift-0-aux1 (succ idx) (succ m) = cong succ (shift-0-aux1 idx m)

shift-0-aux2 : ∀ term m → shift (shift-fn-many m (0 +_)) term == term
shift-0-aux2 (var idx) m = cong var (shift-0-aux1 idx m)
shift-0-aux2 (lam bod) m = cong lam (shift-0-aux2 bod (succ m))
shift-0-aux2 (app fun arg) m = trans (cong (λ x → app x (shift (shift-fn-many m (0 +_)) arg)) (shift-0-aux2 fun m)) (cong (λ x → app fun x) (shift-0-aux2 arg m))

shift-0 : ∀ term → shift (0 +_) term == term
shift-0 term = shift-0-aux2 term 0

shift-succ-aux1 : ∀ a idx m → shift-fn-many m succ (shift-fn-many m (a +_) idx) == shift-fn-many m (succ a +_) idx
shift-succ-aux1 0 idx m = cong (shift-fn-many m succ) (shift-0-aux1 idx m)
shift-succ-aux1 (succ a) idx 0 = refl
shift-succ-aux1 (succ a) 0 (succ m) = refl
shift-succ-aux1 (succ a) (succ idx) (succ m) = cong succ (shift-succ-aux1 (succ a) idx m)

shift-succ-aux2 : ∀ a term m → shift (shift-fn-many m succ) (shift (shift-fn-many m (a +_)) term) == shift (shift-fn-many m (succ a +_)) term
shift-succ-aux2 0 term m = cong (λ x → shift (shift-fn-many m succ) x) (shift-0-aux2 term m)
shift-succ-aux2 (succ a) (var idx) m = cong var (shift-succ-aux1 (succ a) idx m)
shift-succ-aux2 (succ a) (lam bod) m = cong lam (shift-succ-aux2 (succ a) bod (succ m))
shift-succ-aux2 (succ a) (app fun arg) m =
  let term1 = shift (shift-fn-many m succ) (shift (shift-fn-many m (succ a +_)) arg)
      term2 = shift (shift-fn-many m (succ (succ a) +_)) fun
  in trans (cong (λ x → app x term1) (shift-succ-aux2 (succ a) fun m)) (cong (app term2) (shift-succ-aux2 (succ a) arg m))

shift-succ : ∀ a term → shift succ (shift (a +_) term) == shift (succ a +_) term
shift-succ a term = shift-succ-aux2 a term 0

shift-add : ∀ a b term → shift (a +_) (shift (b +_) term) == shift ((a + b) +_) term
shift-add 0 b term = shift-0 (shift (b +_) term)
shift-add (succ a) b term =
  begin
    shift (succ a +_) (shift (b +_) term)
  ==[ sym (shift-succ a (shift (b +_) term)) ]
    shift succ (shift (a +_) (shift (b +_) term))
  ==[ cong (shift succ) (shift-add a b term) ]
    shift succ (shift ((a + b) +_) term)
  ==[ shift-succ (a + b) term ]
    shift ((succ a + b) +_) term
  qed

at-lemma1 : ∀ m idx arg → m == idx → at m arg idx == shift (m +_) arg
at-lemma1 0 0 arg eq = sym (shift-0 arg)
at-lemma1 (succ m) (succ idx) arg eq = trans (cong (shift succ) (at-lemma1 m idx arg (succ-inj eq))) (shift-succ m arg)

at-lemma2 : ∀ m idx arg → m < (succ idx) → at m arg (succ idx) == var idx
at-lemma2 0 idx arg _ = refl
at-lemma2 (succ m) (succ idx) arg (<succ idx<m) = cong (shift succ) (at-lemma2 m idx arg idx<m)

at-lemma3 : ∀ m idx arg → idx < m → at m arg idx == var idx
at-lemma3 (succ m) 0 arg _ = refl
at-lemma3 (succ m) (succ idx) arg (<succ idx<m) = cong (shift succ) (at-lemma3 m idx arg idx<m)

shift-fn-lemma1 : (n m p : Nat) → m <= n → shift-fn-many m (p +_) n == (p + n)
shift-fn-lemma1 n 0 p _ = refl
shift-fn-lemma1 (succ n) (succ m) 0 (<=succ lte) = cong succ (shift-fn-lemma1 n m 0 lte)
shift-fn-lemma1 (succ n) (succ m) (succ p) (<=succ lte) =
  begin
    succ (shift-fn-many m (succ p +_) n)
  ==[ cong succ (shift-fn-lemma1 n m (succ p) lte) ]
    succ (succ (p + n))
  ==[ sym (add-n-succ (succ p) n) ]
    (succ p + succ n)
  qed

shift-fn-lemma2 : (fn : Nat → Nat) → (n m : Nat) → (succ n) <= m → shift-fn-many m fn n == n
shift-fn-lemma2 fn 0 (succ m) (<=succ lte) = refl
shift-fn-lemma2 fn (succ n) (succ m) (<=succ lte) = cong succ (shift-fn-lemma2 fn n m lte)

shift-fn-lemma3 : (n m p : Nat) → Or (shift-fn-many m (p +_) n == n) (shift-fn-many m (p +_) n == (p + n))
shift-fn-lemma3 n m p with <=-total m n
...                   | or0 x = or1 (shift-fn-lemma1 n m p x)
...                   | or1 x = or0 (shift-fn-lemma2 (p +_) n m x)

-- Shifting a term doesn't affect its size
shift-preserves-size : ∀ fn term → size (shift fn term) == size term
shift-preserves-size fn (var idx)     = refl
shift-preserves-size fn (lam bod)     = cong succ (shift-preserves-size (shift-fn fn) bod)
shift-preserves-size fn (app fun arg) =
  let a = shift-preserves-size fn fun
      b = shift-preserves-size fn arg
      c = refl {x = size fun + size arg}
      d = rwt (λ x → (x + (size arg))          == (size fun + size arg)) (sym a) c
      e = rwt (λ x → (size (shift fn fun) + x) == (size fun + size arg)) (sym b) d
  in  cong succ e

-- Helper function
subst-miss-size : (n : Nat) → (bidx : Nat) → (arg : Term) → Not(bidx == n) → size (at n arg bidx) == 0
subst-miss-size (succ n) (succ bidx) arg s = trans (shift-preserves-size succ (at n arg bidx)) (subst-miss-size n bidx arg (modus-tollens (cong succ) s))
subst-miss-size (succ n) zero        arg s = refl
subst-miss-size zero     (succ bidx) arg s = refl
subst-miss-size zero     zero        arg s = absurd (s refl)

-- Helper function
subst-hit-size : (n : Nat) → (bidx : Nat) → (arg : Term) → bidx == n → size (at n arg bidx) == size arg
subst-hit-size (succ n) (succ bidx) arg s = trans (shift-preserves-size succ (at n arg bidx)) (subst-hit-size n bidx arg (succ-inj s))
subst-hit-size (succ n) zero        arg ()
subst-hit-size zero     (succ bidx) arg ()
subst-hit-size zero     zero        arg s = refl

-- Converts the size of a substitution into a mathematical expression
-- That is, size(t[x <- a]) == size(t) + uses(x, t) * size(a)
size-after-subst : ∀ n bod arg → size (subst (at n arg) bod) == (size bod + (uses bod n * size arg))
size-after-subst n (var bidx) arg with same bidx n | inspect (same bidx) n
size-after-subst n (var bidx) arg | true           | its eq = rwt (λ x → size (at n arg bidx) == x) (sym (add-n-0 (size arg))) (subst-hit-size n bidx arg (same-true bidx n eq))
size-after-subst n (var bidx) arg | false          | its eq = subst-miss-size n bidx arg (same-false bidx n eq)
size-after-subst n (lam bbod) arg =
  let a = size-after-subst (succ n) bbod arg
      b = rwt (λ x → size (subst x bbod) == (size bbod + (uses bbod (succ n) * size arg))) refl a
  in  cong succ b
size-after-subst n (app bfun barg) arg =
  let a = size-after-subst n bfun arg
      b = size-after-subst n barg arg
      c = refl {x = (size (subst (at n arg) bfun) + size (subst (at n arg) barg))}
      d = rwt (λ x → (x + size (subst (at n arg) barg)) == (size (subst (at n arg) bfun) + size (subst (at n arg) barg))) a c
      e = rwt (λ x → ((size bfun + (uses bfun n * size arg)) + x) == (size (subst (at n arg) bfun) + size (subst (at n arg) barg))) b d
      f = add-inner-swap (size bfun) (uses bfun n * size arg) (size barg) (uses barg n * size arg)
      g = sym (rwt (λ x → x == (size (subst (at n arg) bfun) + size (subst (at n arg) barg))) f e)
      h = sym (mul-rightdist (uses bfun n) (uses barg n) (size arg))
      i = rwt (λ x → (size (subst (at n arg) bfun) + size (subst (at n arg) barg)) == ((size bfun + size barg) + x)) h g
  in  cong succ i

uses-0-lemma : (idx n : Nat) -> Not (idx == n) -> uses (var idx) n == 0
uses-0-lemma idx n neq with same idx n | inspect (same idx) n
uses-0-lemma idx n neq | true          | its eq =  absurd (neq (same-true idx n eq))
uses-0-lemma idx n neq | false         | its eq = refl

uses-1-lemma : (idx n : Nat) -> idx == n -> uses (var idx) n == 1
uses-1-lemma idx n eq with same idx n | inspect (same idx) n
uses-1-lemma idx n eq | true          | its eq' = refl
uses-1-lemma idx n eq | false         | its eq'  = absurd (same-false idx n eq' eq)

uses-shift-add-lemma : (term : Term) -> (n p m : Nat) -> n < p -> uses (shift (shift-fn-many m (p +_)) term) (m + n) == 0
uses-shift-add-lemma (var idx) n (succ p) 0 lt = let neq = modus-tollens sym (<-to-not-== (<-incr-r idx lt)) in uses-0-lemma (succ p + idx) n neq
uses-shift-add-lemma (var 0) n (succ p) (succ m) lt = refl
uses-shift-add-lemma (var (succ idx)) n (succ p) (succ m) lt = uses-shift-add-lemma (var idx) n (succ p) m lt
uses-shift-add-lemma (lam bod) n (succ p) m lt = uses-shift-add-lemma bod n (succ p) (succ m) lt
uses-shift-add-lemma (app fun arg) n (succ p) m lt = trans (cong (_+ uses (shift (shift-fn-many m (succ p +_)) arg) (m + n)) (uses-shift-add-lemma fun n (succ p) m lt)) (uses-shift-add-lemma arg n (succ p) m lt)

uses-shift-add : (term : Term) -> (n p : Nat) -> n < p -> uses (shift (p +_) term) n == 0
uses-shift-add term n p lt = uses-shift-add-lemma term n p 0 lt

var-uses<=1 : {idx n : Nat} -> uses (var idx) n <= 1
var-uses<=1 {0} {0} = <=-refl'
var-uses<=1 {0} {succ n} = <=zero
var-uses<=1 {succ idx} {0} = <=zero
var-uses<=1 {succ idx} {succ n} = var-uses<=1 {idx} {n}

uses-add-lemma : (term : Term) → (n m p : Nat) → m <= n → uses (shift (shift-fn-many m (p +_)) term) (p + n) == uses term n
uses-add-lemma (var idx) n 0 0 _ = refl
uses-add-lemma (var idx) n 0 (succ p) _ =
    uses (var (succ p + idx)) (succ p + n)
  ==[]
    uses (var (p + idx)) (p + n)
  ==[ uses-add-lemma (var idx) n 0 p <=zero ]
    uses (var idx) n
  qed
uses-add-lemma (var idx) (succ n) (succ m) p (<=succ m<=n) with <=-total (succ m) idx
uses-add-lemma (var idx) (succ n) (succ m) p (<=succ m<=n) | or0 1+m<=idx  =
  begin
    uses (shift (shift-fn-many (succ m) (p +_)) (var idx)) (p + succ n)
  ==[]
    uses (var (shift-fn-many (succ m) (p +_) idx)) (p + succ n)
  ==[ cong (λ x → uses (var x) (p + succ n)) (shift-fn-lemma1 idx (succ m) p 1+m<=idx) ]
    uses (var (p + idx)) (p + succ n)
  ==[ uses-n-step p ]
    uses (var idx) (succ n)
  qed
uses-add-lemma (var idx) (succ n) (succ m) p (<=succ m<=n) | or1 (<=succ idx<=m) =
  let idx<=n = <=-trans idx<=m m<=n
      neq1 = <-to-not-== (<=-to-< (<=-incr-l p (<=succ idx<=n)))
      neq2 = <-to-not-== (<=-to-< (<=succ idx<=n))
  in
    begin
    uses (var (shift-fn-many (succ m) (_+_ p) idx)) (p + succ n)
  ==[ cong (λ x → uses (var x) (p + succ n)) (shift-fn-lemma2 (p +_) idx (succ m) (<=succ idx<=m)) ]
    uses (var idx) (p + succ n)
  ==[ uses-0-lemma idx (p + succ n) neq1 ]
    0
  ==[ sym (uses-0-lemma idx (succ n) neq2) ]
    uses (var idx) (succ n)
  qed
uses-add-lemma (app fun arg) n m p leq =
  begin
    uses (shift (shift-fn-many m (p +_)) (app fun arg)) (p + n)
  ==[]
    uses (shift (shift-fn-many m (p +_)) fun) (p + n) + uses (shift (shift-fn-many m (p +_)) arg) (p + n)
  ==[ cong (_+ uses (shift (shift-fn-many m (p +_)) arg) (p + n)) (uses-add-lemma fun n m p leq)  ]
    uses fun n + uses (shift (shift-fn-many m (p +_)) arg) (p + n)
  ==[ cong (uses fun n +_) (uses-add-lemma arg n m p leq)  ]
    uses (app fun arg) n
    qed
uses-add-lemma (lam bod) n m p leq =
  begin
    uses (shift (shift-fn-many m (p +_)) (lam bod)) (p + n)
  ==[]
    uses (shift (shift-fn-many (succ m) (p +_)) bod) (succ p + n)
  ==[ cong (λ x → uses (shift (shift-fn-many (succ m) (p +_)) bod) x) (sym (add-n-succ p n)) ]
    uses (shift (shift-fn-many (succ m) (p +_)) bod) (p + succ n)
  ==[ uses-add-lemma bod (succ n) (succ m) p (<=succ leq) ]
    uses bod (succ n)
  ==[]
    uses (lam bod) n
  qed

uses-add : (term : Term) → (n p : Nat) → uses (shift (p +_) term) (p + n) == uses term n
uses-add term n p = uses-add-lemma term n 0 p <=zero

uses-succ : (term : Term) → (n : Nat) → uses (shift succ term) (succ n) == uses term n
uses-succ term n = uses-add-lemma term n 0 1 <=zero

uses-subst-0 : (n m : Nat) → (arg bod : Term) → (uses bod m) == 0 → uses (subst (at m arg) bod) (m + n) == uses bod (succ (m + n))
uses-subst-0 n 0 arg (var (succ idx)) pf = sym (uses-succ (var idx) n)
uses-subst-0 n (succ m) arg (var 0) pf = refl
uses-subst-0 n (succ m) arg (var (succ idx)) pf =
    uses (shift succ (at m arg idx)) (succ m + n)
  ==[ uses-succ (at m arg idx) (m + n) ]
    uses (at m arg idx) (m + n)
  ==[ uses-subst-0 n m arg (var idx) pf ]
    uses (var idx) (succ m + n)
  ==[ sym (uses-succ (var idx) (succ m + n)) ]
    uses (var (succ idx)) (succ (succ m + n))
  qed
uses-subst-0 n m arg (lam bod) pf = uses-subst-0 n (succ m) arg bod pf
uses-subst-0 n m arg (app fun arg') pf =
  let and eq1 eq2 = add-no-inverse (uses fun m) (uses arg' m) pf
  in
  begin
  begin
    uses (subst (at m arg) fun) (m + n) + uses (subst (at m arg) arg') (m + n)
  ==[ cong (_+ uses (subst (at m arg) arg') (m + n)) (uses-subst-0 n m arg fun eq1) ]
    uses fun (succ m + n) + uses (subst (at m arg) arg') (m + n)
  ==[ cong (uses fun (succ m + n) +_) (uses-subst-0 n m arg arg' eq2) ]
    uses fun (succ m + n) + uses arg' (succ m + n)
  qed

uses-subst-1 : (n m : Nat) → (arg bod : Term) → (uses bod m) == 1 → (uses (subst (at m arg) bod) (m + n)) == (uses bod (succ (m + n)) + uses arg n)
uses-subst-1 n 0 arg (var 0) pf = refl
uses-subst-1 n (succ m) arg (var (succ idx)) pf =
  begin
    uses (shift succ (at m arg idx)) (succ m + n)
  ==[ uses-succ (at m arg idx) (m + n) ]
    uses (at m arg idx) (m + n)
  ==[ uses-subst-1 n m arg (var idx) pf ]
    uses (var idx) (succ m + n) + uses arg n
  ==[ cong (_+ uses arg n) (sym (uses-succ (var idx) (succ m + n))) ]
    uses (var (succ idx)) (succ (succ m + n)) + uses arg n
  qed
uses-subst-1 n m arg (lam bod) pf = uses-subst-1 n (succ m) arg bod pf
uses-subst-1 n m arg (app fun arg') pf =
  let case0 x =
        let and eq1 eq2 = x in
        begin
          uses (subst (at m arg) fun) (m + n) + uses (subst (at m arg) arg') (m + n)
        ==[ cong (_+ uses (subst (at m arg) arg') (m + n)) (uses-subst-0 n m arg fun eq1)]
          uses fun (succ m + n) + uses (subst (at m arg) arg') (m + n)
        ==[ cong (uses fun (succ m + n) +_) (uses-subst-1 n m arg arg' eq2) ]
          uses fun (succ m + n) + (uses arg' (succ m + n) + uses arg n)
        ==[ add-assoc (uses fun (succ m + n)) (uses arg' (succ m + n)) (uses arg n) ]
          (uses fun (succ m + n) + uses arg' (succ m + n)) + uses arg n
        qed
      case1 x =
        let and eq1 eq2 = x in
        begin
          uses (subst (at m arg) fun) (m + n) + uses (subst (at m arg) arg') (m + n)
        ==[ cong (uses (subst (at m arg) fun) (m + n) +_) (uses-subst-0 n m arg arg' eq1)]
          uses (subst (at m arg) fun) (m + n) + uses arg' (succ m + n)
        ==[ cong (_+ uses arg' (succ m + n)) (uses-subst-1 n m arg fun eq2) ]
          (uses fun (succ m + n) + uses arg n) + uses arg' (succ m + n)
        ==[ add-right-swap (uses fun (succ m + n)) (uses arg n) (uses arg' (succ m + n)) ]
          (uses fun (succ m + n) + uses arg' (succ m + n)) + uses arg n
        qed
  in case-or (+-eq-1 (uses fun m) (uses arg' m) pf) case0 case1

reduce-uses-lemma : (n : Nat) → (arg bod : Term) → uses bod 0 <= 1 → (uses (subst (at 0 arg) bod) n) <= (uses bod (succ n) + uses arg n)
reduce-uses-lemma n arg bod pf with uses bod 0             | inspect (uses bod) 0
reduce-uses-lemma n arg bod _            | 0               | its e = <=-incr-r (uses arg n) (<=-refl (uses-subst-0 n 0 arg bod e))
reduce-uses-lemma n arg bod _            | 1               | its e = <=-refl (uses-subst-1 n 0 arg bod e)
reduce-uses-lemma n arg bod (<=succ leq) | (succ (succ m)) | its e = absurd (succ-not-<=-0 leq)

reduce-uses : (n : Nat) → (t : Term) → IsAffine t → uses (reduce t) n <= uses t n
reduce-uses n (var idx) _ = <=-refl'
reduce-uses n (lam bod) (lam-affine _ af) = reduce-uses (succ n) bod af
reduce-uses n (app (var idx) arg) (app-affine _ af) = <=-cong-add-l (uses (var idx) n) (reduce-uses n arg af)
reduce-uses n (app (app ffun farg) arg) (app-affine (app-affine ffun-af farg-af) arg-af) =
  let pf1 = reduce-uses n (app ffun farg) (app-affine ffun-af farg-af)
      pf2 = reduce-uses n arg arg-af
  in
  begin<=
    uses (reduce (app (app ffun farg) arg)) n
  <=[]
    uses (app (reduce (app ffun farg)) (reduce arg)) n
  <=[]
    uses (reduce (app ffun farg)) n + uses (reduce arg) n
  <=[ <=-additive pf1 pf2 ]
    uses (app ffun farg) n + uses arg n
  <=[]
    uses (app (app ffun farg) arg) n
  qed<=
reduce-uses n (app (lam bod) arg) (app-affine (lam-affine eq bod-af) arg-af) =
  let pf1 = reduce-uses n (lam bod) (lam-affine eq bod-af)
      pf2 = reduce-uses n arg arg-af
  in
  begin<=
    uses (reduce (app (lam bod) arg)) n
  <=[]
    uses (subst (at 0 (reduce arg)) (reduce bod)) n
  <=[ reduce-uses-lemma n (reduce arg) (reduce bod) (<=-trans (reduce-uses 0 bod bod-af) eq) ]
     uses (reduce bod) (succ n) + uses (reduce arg) n
  <=[ <=-additive pf1 pf2 ]
    uses bod (succ n) + uses arg n
  <=[]
    uses (app (lam bod) arg) n
  qed<=

uses-subst-lemma : (n m : Nat) → n < m → (arg bod : Term) → (uses (subst (at m arg) bod) n) <= uses bod n
uses-subst-lemma n m lt arg (var idx) with nat-trichotomy m idx
...                                    | or0 m=idx =
  begin<=
    uses (at m arg idx) n
  <=[ <=-refl (cong (λ x → uses x n) (at-lemma1 m idx arg m=idx)) ]
    uses (shift (m +_) arg) n
  <=[ <=-refl (uses-shift-add arg n m lt) ]
    0
  <=[ <=zero ]
    uses (var idx) n
  qed<=
uses-subst-lemma n m lt arg (var (succ idx)) | or1 (or0 m<1+idx) =
  let n!=idx = modus-tollens sym (<-to-not-== (<-comb-<= lt (<-to-<=' m<1+idx)))
  in begin<=
    uses (at m arg (succ idx)) n
  <=[ <=-refl (cong (λ x → uses x n) (at-lemma2 m idx arg m<1+idx)) ]
    uses (var idx) n
  <=[ <=-refl (uses-0-lemma idx n n!=idx) ]
    0
  <=[ <=zero ]
    uses (var (succ idx)) n
  qed<=
uses-subst-lemma n (succ m) lt arg (var idx) | or1 (or1 idx<1+m) =
  begin<=
    uses (at (succ m) arg idx) n
  <=[ <=-refl (cong (λ x → uses x n) (at-lemma3 (succ m) idx arg idx<1+m)) ]
    uses (var idx) n
  qed<=
uses-subst-lemma n m lt arg (lam bod) = uses-subst-lemma (succ n) (succ m) (<succ lt) arg bod
uses-subst-lemma n m lt arg (app fun arg') =
  let rec1 = uses-subst-lemma n m lt arg fun
      rec2 = uses-subst-lemma n m lt arg arg'
      term1 = uses fun n
      term2 = uses (subst (at m arg) arg') n
  in <=-trans (<=-cong-add-r term2 rec1) (<=-cong-add-l term1 rec2)

uses-shift-succ1 : (term : Term) -> (m p : Nat) -> uses (shift (shift-fn-many (succ p + m) succ) term) p == uses term p
uses-shift-succ1 (var idx) m p with <=-trichotomy idx p
...               | or0 refl =
  begin
    uses (var (shift-fn-many (succ idx + m) succ idx)) idx
  ==[ cong (λ x → uses (var x) idx) (shift-fn-lemma2 succ idx (succ idx + m) (<=-incr-r m <=-refl')) ]
    uses (var idx) idx
  qed
...               | or1 (or0 1+idx<=p) =
  begin
    uses (var (shift-fn-many (succ p + m) succ idx)) p
  ==[ cong (λ x → uses (var x) p) (shift-fn-lemma2 succ idx (succ p + m) (<=-incr-r m (<=-incr-l 1 1+idx<=p)))  ]
    uses (var idx) p
  qed
...               | or1 (or1 1+p<=idx) =
  let idx!=p = modus-tollens sym (<-to-not-== (<=-to-< 1+p<=idx))
      idx!=1+p = modus-tollens sym (<-to-not-== (<=-to-< (<=-incr-l 1 1+p<=idx)))
      case1 x = trans (cong (λ x → uses (var x) p) x) (uses-0-lemma idx p idx!=p)
      case2 x = trans (cong (λ x → uses (var x) p) x) (uses-0-lemma (succ idx) p idx!=1+p)
  in begin
    uses (var (shift-fn-many (succ p + m) succ idx)) p
  ==[ case-or (shift-fn-lemma3 idx (succ p + m) 1) case1 case2 ]
    0
  ==[ sym (uses-0-lemma idx p idx!=p) ]
    uses (var idx) p
  qed
uses-shift-succ1 (lam bod) m p = uses-shift-succ1 bod m (succ p)
uses-shift-succ1 (app fun arg) m p = trans (cong (_+ uses (shift (shift-fn-many (succ p + m) succ) arg) p) (uses-shift-succ1 fun m p)) (cong (uses fun p +_) (uses-shift-succ1 arg m p))

shift-succ-affine-lemma : (term : Term) → IsAffine term → (m : Nat) → IsAffine (shift (shift-fn-many m succ) term)
shift-succ-affine-lemma (var idx) af m = var-affine
shift-succ-affine-lemma (app fun arg) (app-affine fun-af arg-af) m = app-affine (shift-succ-affine-lemma fun fun-af m) (shift-succ-affine-lemma arg arg-af m)
shift-succ-affine-lemma (lam bod) (lam-affine leq af) m = let rec = shift-succ-affine-lemma bod af (succ m) in lam-affine (<=-trans (<=-refl (uses-shift-succ1 bod m 0)) leq) rec

shift-succ-affine : (term : Term) → IsAffine term → IsAffine (shift succ term)
shift-succ-affine term af = shift-succ-affine-lemma term af 0

reduce-affine-lemma : (arg bod : Term) → IsAffine arg → IsAffine bod → (m : Nat) → (uses bod m) <= 1 → IsAffine (subst (at m arg) bod)
reduce-affine-lemma arg (var 0) arg-af _ 0 _ = arg-af
reduce-affine-lemma arg (var 0) arg-af _ (succ m) _ = var-affine
reduce-affine-lemma arg (var (succ idx)) arg-af _ 0 _ = var-affine
reduce-affine-lemma arg (var (succ idx)) arg-af _ (succ m) pf = shift-succ-affine (at m arg idx) (reduce-affine-lemma arg (var idx) arg-af var-affine m (var-uses<=1 {idx} {m}))
reduce-affine-lemma arg (lam bod) arg-af (lam-affine leq bod-af) m pf =
  lam-affine (<=-trans (uses-subst-lemma 0 (succ m) <zero arg bod) leq) (reduce-affine-lemma arg bod arg-af bod-af (succ m) pf)
reduce-affine-lemma arg (app fun arg') arg-af (app-affine fun-af arg'-af) m pf =
  app-affine (reduce-affine-lemma arg fun arg-af fun-af m (<=-trans (<=-incr-r (uses arg' m) <=-refl') pf)) (reduce-affine-lemma arg arg' arg-af arg'-af m (<=-trans (<=-incr-l (uses fun m) <=-refl') pf))

reduce-affine : {t : Term} → IsAffine t → IsAffine (reduce t)
reduce-affine {var idx} af = var-affine
reduce-affine {lam bod} (lam-affine leq bod-af) = lam-affine (<=-trans (reduce-uses 0 bod bod-af) leq) (reduce-affine bod-af)
reduce-affine {app (var idx) arg} (app-affine _ arg-af) = app-affine var-affine (reduce-affine arg-af)
reduce-affine {app (app ffun farg) arg} (app-affine fun-af arg-af) = app-affine (reduce-affine fun-af) (reduce-affine arg-af)
reduce-affine {app (lam bod) arg} (app-affine (lam-affine leq bod-af) arg-af) =
  let red-arg-af = (reduce-affine arg-af)
      red-bod-af = (reduce-affine bod-af)
  in reduce-affine-lemma (reduce arg) (reduce bod) red-arg-af red-bod-af 0 (<=-trans (reduce-uses 0 bod bod-af) leq)

-- Reducing an affine term either reduces its size or keeps it the same
reduce<= : (t : Term) → IsAffine t → size (reduce t) <= size t
reduce<= (var idx) _ = <=zero
reduce<= (lam bod) (lam-affine _ af) = <=succ (reduce<= bod af)
reduce<= (app (var fidx) arg) (app-affine _ af) = <=succ (reduce<= arg af)
reduce<= (app (app ffun farg) arg) (app-affine af-fun af-arg) = <=succ (<=-additive (reduce<= (app ffun farg) af-fun) (reduce<= arg af-arg))
reduce<= (app (lam fbod) arg) (app-affine (lam-affine leq af-bod) af-arg) =
  let step1 = <=-refl (size-after-subst 0 (reduce fbod) (reduce arg))
      step2 = <=-cong-add-r (uses (reduce fbod) 0 * size (reduce arg)) (reduce<= fbod af-bod)
      step3 = <=-cong-add-l (size fbod) (<=-cong-mul-l (uses (reduce fbod) 0) (reduce<= arg af-arg))
      step4 = <=-cong-add-l (size fbod) (<=-cong-mul-r (size arg) (reduce-uses 0 fbod af-bod))
      step5 = <=-cong-add-l (size fbod) (<=-cong-mul-r (size arg) leq)
      step6 = <=-cong-add-l (size fbod) (<=-refl (add-n-0 (size arg)))
      step7 = <=-incr-l 2 <=-refl'
  in
  begin<=
    size (reduce (app (lam fbod) arg))
  <=[]
    size (subst (at 0 (reduce arg)) (reduce fbod))
  <=[ step1 ]
    size (reduce fbod) + (uses (reduce fbod) 0 * size (reduce arg))
  <=[ step2 ]
    size fbod + (uses (reduce fbod) 0 * size (reduce arg))
  <=[ step3 ]
    size fbod + (uses (reduce fbod) 0 * size arg)
  <=[ step4 ]
    size fbod + (uses fbod 0 * size arg)
  <=[ step5 ]
    size fbod + (1 * size arg)
  <=[ step6 ]
    size fbod + size arg
  <=[ step7 ]
    succ (succ (size fbod + size arg))
  <=[]
    size (app (lam fbod) arg)
  qed<=

-- Reducing an affine term with redexes reduces its size
reduce< : (t : Term) → IsAffine t → HasRedex t → size (reduce t) < size t
reduce< (var idx) _ ()
reduce< (lam bod) (lam-affine _ af) (lam-redex hr) = <succ (reduce< bod af hr)
reduce< (app (var fidx) arg) (app-affine _ af) (app-redex (or1 o1)) = <succ (reduce< arg af o1)
reduce< (app (app ffun farg) arg) (app-affine leq af) (app-redex (or0 o0)) =
  <succ (<-additive (reduce< (app ffun farg) leq o0) (reduce<= arg af))
reduce< (app (app ffun farg) arg) (app-affine leq af) (app-redex (or1 o1)) =
  let a = reduce<= (app ffun farg) leq
      b = reduce< arg af o1
      c = <-additive' a b
  in  <succ c
reduce< (app (lam fbod) arg) (app-affine (lam-affine leq af-bod) af-arg) foundredex =
  let step1 = <=-refl (size-after-subst 0 (reduce fbod) (reduce arg))
      step2 = <=-cong-add-r (uses (reduce fbod) 0 * size (reduce arg)) (reduce<= fbod af-bod)
      step3 = <=-cong-add-l (size fbod) (<=-cong-mul-l (uses (reduce fbod) 0) (reduce<= arg af-arg))
      step4 = <=-cong-add-l (size fbod) (<=-cong-mul-r (size arg) (reduce-uses 0 fbod af-bod))
      step5 = <=-cong-add-l (size fbod) (<=-cong-mul-r (size arg) leq)
      step6 = <=-cong-add-l (size fbod) (<=-refl (add-n-0 (size arg)))
      step7 = <=-incr-l 1 <=-refl'
  in
  begin<
    size (reduce (app (lam fbod) arg))
  <='[]
    size (subst (at 0 (reduce arg)) (reduce fbod))
  <='[ step1 ]
    size (reduce fbod) + (uses (reduce fbod) 0 * size (reduce arg))
  <='[ step2 ]
    size fbod + (uses (reduce fbod) 0 * size (reduce arg))
  <='[ step3 ]
    size fbod + (uses (reduce fbod) 0 * size arg)
  <='[ step4 ]
    size fbod + (uses fbod 0 * size arg)
  <='[ step5 ]
    size fbod + (1 * size arg)
  <='[ step6 ]
    size fbod + size arg
  <[ n-<-succ  ]
    succ (size fbod + size arg)
  <=[ step7  ]
    succ (succ (size fbod + size arg))
  <=[]
    size (app (lam fbod) arg)
  qed<

reduce-fix : (t : Term) → IsNormal t → reduce t == t
reduce-fix (var idx) _ = refl
reduce-fix (lam bod) (lam-normal bod-norm) = cong lam (reduce-fix bod bod-norm)
reduce-fix (app (var idx) arg) (app-var-normal arg-norm) = cong (λ x → app (var idx) x) (reduce-fix arg arg-norm)
reduce-fix (app (app fun arg') arg) (app-app-normal app-norm arg-norm) = trans (cong (λ x → app x (reduce arg)) (reduce-fix (app fun arg') app-norm)) (cong (λ x → app (app fun arg') x) (reduce-fix arg arg-norm))

reduce-fix' : (t : Term) → IsAffine t → reduce t == t → IsNormal t
reduce-fix' t af eq = noredex-is-normal t (λ hasredex → <-to-not-== (reduce< t af hasredex) (cong size eq))

normalize-aux : (t : Term) → IsAffine t → (len : Nat) → Acc len → len == size t → Term
normalize-aux t af len ac       eq with normal-or-hasredex t
normalize-aux t af len ac       eq | or0 _ = t
normalize-aux t af len (acc pf) eq | or1 hasredex = normalize-aux (reduce t) (reduce-affine af) (size (reduce t)) (pf _ (rwt (size (reduce t) <_) (sym eq) (reduce< t af hasredex))) refl

normalize-aux-lemma : (t : Term) → (af : IsAffine t) → (len : Nat) → (ac ac' : Acc len) → (eq eq' : len == size t) → normalize-aux t af len ac eq == normalize-aux t af len ac' eq'
normalize-aux-lemma t af len ac ac' eq eq' with normal-or-hasredex t
normalize-aux-lemma t af len ac ac' eq eq' | or0 _ = refl
normalize-aux-lemma t af len (acc pf) (acc pf') eq eq' | or1 hasredex =
  normalize-aux-lemma (reduce t) (reduce-affine af) (size (reduce t)) (pf _ (rwt (size (reduce t) <_) (sym eq) (reduce< t af hasredex))) (pf' _ (rwt (size (reduce t) <_) (sym eq') (reduce< t af hasredex))) refl refl

normalize : (t : Term) → IsAffine t  → Term
normalize t af = normalize-aux t af (size t) (<-wf (size t)) refl

normalize-theorem : (t : Term) → (af : IsAffine t)  → IsNormal (normalize t af)
normalize-theorem t af = go t af (size t) (<-wf (size t)) refl
  where
  go : (t : Term) → (af : IsAffine t) → (len : Nat) → (ac : Acc len) → (eq : len == size t) → IsNormal (normalize-aux t af len ac eq)
  go t af len ac       eq with normal-or-hasredex t
  go t af len ac       eq | or0 normal = normal
  go t af len (acc pf) eq | or1 hasredex = go (reduce t) (reduce-affine af) (size (reduce t)) (pf _ (rwt (size (reduce t) <_) (sym eq) (reduce< t af hasredex))) refl

normalize-is-reduce : (t : Term) → (af : IsAffine t) → Sum Nat (λ x → normalize t af == pow reduce x t)
normalize-is-reduce t af =
  let sigma x eq = go t af (size t) (<-wf (size t)) refl
  in sigma x (trans eq (sym (pow==pow' reduce x t)))
  where
  go : (t : Term) → (af : IsAffine t) → (len : Nat) → (ac : Acc len) → (eq : len == size t) → Sum Nat (λ x → normalize-aux t af len ac eq == pow' reduce x t)
  go t af len ac       eq with normal-or-hasredex t
  go t af len ac       eq | or0 normal = sigma 0 refl
  go t af len (acc pf) eq | or1 hasredex =
    let sigma x eq' = go (reduce t) (reduce-affine af) (size (reduce t)) (pf _ (rwt (size (reduce t) <_) (sym eq) (reduce< t af hasredex))) refl
    in sigma (succ x) eq'

normalize-base : (t : Term) → (af : IsAffine t) → IsNormal t → normalize t af == t
normalize-base t af norm with normal-or-hasredex t
normalize-base t af norm | or0 _ = refl
normalize-base t af norm | or1 hasredex = absurd (normal-has-noredex t norm hasredex)

normalize-step : (t : Term) → (af : IsAffine t) → normalize t af == normalize (reduce t) (reduce-affine af)
normalize-step t af with normal-or-hasredex t | normal-or-hasredex (reduce t) | inspect normal-or-hasredex (reduce t) | <-wf (size t)
normalize-step t af | or0 norm                | or0 _                         | _                                     | _ = sym (reduce-fix t norm)
normalize-step t af | or1 hasredex            | x                             | its refl                              | acc pf =
  normalize-aux-lemma (reduce t) (reduce-affine af) (size (reduce t)) (pf _ (reduce< t af hasredex)) (<-wf (size (reduce t))) refl refl 
normalize-step t af | or0 norm                | or1 hasredex                  | _                                     | _ = absurd (normal-has-noredex t norm (rwt HasRedex (reduce-fix t norm) hasredex))

affine-normalizable : (t : Term) → IsAffine t → Normalizable t
affine-normalizable t af =
  let sigma x eq = normalize-is-reduce t af
      pf = ~>>pow reduce reduce-~>> x
  in manystep-normalizable (rwt (t ~>>_) (sym eq) pf) (normal-is-normalizable (normalize-theorem t af))
