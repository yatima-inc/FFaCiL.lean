import YatimaStdLib.Polynomial
import YatimaStdLib.Zmod
import YatimaStdLib.Bit

/-!
# Galois Fields
This module provides the basic data structures necessary to define and work with prime fields
and their extensions.
Here we port some definitions from https://hackage.haskell.org/package/galois-field-1.0.2
-/

/-- The structure of a Galois field on t-/
class GaloisField (K : Type _) where
  plus : K → K → K
  times : K → K → K
  null : K
  ein : K
  minus : K → K → K
  divis : K → K → K
  -- Characteristic `p` of field and order of prime subfield.
  char : Nat
  -- Degree `q` of field as extension field over prime subfield.
  deg : Nat
  -- Frobenius endomorphism `x ↦ x^p` of prime subfield.
  frob : K → K

namespace GaloisField

instance [GaloisField K] : Inhabited K where
  default := null

instance [GaloisField K] : Add K where
  add := plus

instance [GaloisField K] : Mul K where
  mul := times

instance [GaloisField K] : OfNat K (nat_lit 1) where
  ofNat := ein

instance [GaloisField K] : OfNat K (nat_lit 0) where
  ofNat := null

instance [GaloisField K] : Div K where
  div := divis

instance [GaloisField K] : Sub K where
  sub := minus

/-- An `O(log n)` implementation of `galPow` -/
def fastPow [Mul K] [OfNat K (nat_lit 1)] (x : K) (n : Nat) : K := 
  let binExp := n.toBits
  let squares := getSquares [x] (binExp.length)
  binExp.zip squares |>.foldl (init := 1) (fun acc (x, s) => if x == .one then acc * s else acc)
  where getSquares (acc : List K) (n : Nat) : List K :=
    match n with
    | 0 => []
    | 1 => acc
    | n + 1 => getSquares ((acc.headD x) * (acc.headD x) :: acc) n

def galPow [GaloisField K] : K → Nat → K
  | _, 0 => 1
  | x, (k + 1) => x * (galPow x k)

-- TODO: Replace this with `fastPow`?
instance [GaloisField K] : HPow K Nat K where
  hPow := galPow

instance [GaloisField K] : Neg K where
  neg x := 0 - x

/-- Order p^q of field.-/
def order [GaloisField K] : Nat := (char K)^(deg K)

instance : GaloisField (Zmod p) where
  plus := (. + .)
  times := (. * .)
  null := 0
  ein := 1
  minus := (. - .)
  divis := (. / .)
  char := p
  deg := 1
  frob r := r ^ p

/-- The class of a prime subfield of a GaloisField -/
class PrimeField (K : Type _) [GaloisField K] where
  fromP : K → Int

instance : PrimeField (Zmod p) where
  fromP := id

open Polynomial

/-- 
Pre-computed evaluations of the Frobenius for a Galois field for small degree (2 and 3) extensions.
`frobenius P Q` evaluates the Frobenius of `Q` in the extension of `K` defined by `P`. 
-/
def frobenius [GaloisField K] [BEq K] :
  Polynomial K → Polynomial K → Option (Polynomial K)
  | _,  #[] => .some #[]
  | _, #[a] => .some #[frob a]
  | #[x,y,z], #[a,b] =>
    if y == 0 && z == 1 then
      let nxq : K := (-x) ^ (char K >>> 1)
      .some #[frob a, frob b * nxq]
    else .none
  | #[a,b], #[x,y₁,y₂,z] =>
    if y₁ == 0 && y₂ == 0 && z == 1 then
      let (q,r) := Int.quotRem (char K) 3
      let nxq : K := (-x) ^ q
      if (char K) == 3 then .some #[frob a - frob b * x] else
      if r == 1 then .some #[frob a, frob b * nxq] else
      .some #[frob a, 0, frob b * nxq]
    else .none
  | #[a,b,c], #[x,y₁,y₂,z] =>
    if y₁ == 0 && y₂ == 0 && z == 1 then
      let (q,r) := Int.quotRem (char K) 3
      let nxq : K := (-x) ^ q
      if (char K) == 3 then .some #[frob a - (frob b - frob c * x) * x] else
      if r == 1 then .some #[frob a, frob b * nxq, frob c * nxq * nxq] else
      .some #[frob a, frob c * (-x) * nxq * nxq, frob b * nxq]
    else .none
  | _,_ => .none

/-- 
The inductive representing field elements in an Extension field of `K` defined by a polynomial `P`
-/
def Extension (K : Type _) [GaloisField K] (_ : Polynomial K) := Polynomial K

instance {P : Polynomial K} [GaloisField K] : Coe (Polynomial K) (Extension K P) where
  coe := id

def Extension.defPoly {K : Type _} [GaloisField K] {P : Polynomial K} (_ : Extension K P) 
  : Polynomial K := P

/-- 
Calculates powers of polynomials
-/
def polyPow {K : Type _} [GaloisField K] [BEq K] : Polynomial K → Nat → Polynomial K
  | _, 0 => #[1]
  | p, k + 1 => polyMul p (polyPow p k)

def polyInv {K : Type _} [GaloisField K] [BEq K] (Q P : Polynomial K) : Polynomial K :=
  let (a, _, g) := polyEuc Q P
  if g == #[1] then a else #[0]

instance [GaloisField K] [BEq K] : Mul (Extension K P) where
  mul := polyMul

instance [GaloisField K] : OfNat (Extension K P) (nat_lit 1) := ⟨#[1]⟩

instance [GaloisField K] [BEq K]: GaloisField (Extension K P) where
  plus := polyAdd
  times := (· * ·)
  null := #[0]
  ein := 1
  minus := polySub
  divis f g := polyMul (polyInv g P) f
  char := char K
  deg := (deg K) * degree (P)
  frob e :=
    match frobenius e P with
    | .some z => z
    | .none => fastPow e (char K)

def fieldNorm [GaloisField K] [BEq K] (a : Extension K P) := polyMod a P

instance [GaloisField K] [BEq K] : BEq (Extension K P) where
  beq a b := fieldNorm a == fieldNorm b

class TowerOfFields (K : Type _) (L : Type _) [GaloisField K] [GaloisField L] where
  embed : K → L

instance extensionFieldTower [GaloisField K] [BEq K] : TowerOfFields K (Extension K P) where
  embed x := #[x]

instance [GaloisField L] [GaloisField K] [BEq K] [BEq L]
         [t₁ : TowerOfFields K L] : TowerOfFields K (Extension L Q) where
  embed := 
    let t₂ := extensionFieldTower
    t₂.embed ∘ t₁.embed

-- fields with square roots
inductive Residue where
  | zero
  | quadraticResidue
  | quadraticNonResidue
deriving Repr

def legendreSymbol [GaloisField K] [BEq K] (x : K) : Residue :=
  let pow := (char K) ^ (deg K) >>> 1
  let exp := fastPow x pow
  if exp == 1 then .quadraticResidue else 
  if exp == -1 then .quadraticNonResidue else
    .zero

class SqrtField (F : Type _) where
  legendre : F → Residue
  sqrt : F → Option F

end GaloisField