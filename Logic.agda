module Logic where

-- Empty set
data Empty : Set where

absurd : {A : Set} -> Empty -> A
absurd ()

Not : Set -> Set
Not A = A -> Empty

modus-tollens : {A B : Set} -> (A -> B) -> (Not B -> Not A)
modus-tollens f nb a = nb (f a)

-- Set with one element
data Unit : Set where
  unit : Unit

-- Set with two elements
data Bool : Set where
  true  : Bool
  false : Bool
{-# BUILTIN BOOL  Bool  #-}
{-# BUILTIN TRUE  true  #-}
{-# BUILTIN FALSE false #-}

-- Simple pairs (a.k.a., logical And)
data And (A : Set) (B : Set) : Set where
  and : (a : A) → (b : B) → And A B

-- First projection
fst : ∀ {A B} → And A B → A
fst (and a b) = a

-- Second projection
snd : ∀ {A B} → And A B → B
snd (and a b) = b

-- Simple disjunctions (a.k.a. logical Or)
data Or (A : Set) (B : Set) : Set where
  or0 : (a : A) → Or A B
  or1 : (b : B) → Or A B

-- Dependent elimination
d-case-or : {A B : Set} {C : Or A B -> Set} ->
            (m : (Or A B)) -> 
            ((a : A) -> C (or0 a)) ->
            ((b : B) -> C (or1 b)) ->
            C m
d-case-or (or0 a) inj0 inj1 = inj0 a
d-case-or (or1 b) inj0 inj1 = inj1 b

-- Nondependent elimination
case-or : {A B C : Set} -> Or A B -> (A -> C) -> (B -> C) -> C
case-or {A} {B} {C} x f g = d-case-or {A} {B} {\ x -> C} x f g

record Sum (A : Set) (B : A → Set) : Set where
  constructor sigma
  field
    proj1 : A
    proj2 : B proj1