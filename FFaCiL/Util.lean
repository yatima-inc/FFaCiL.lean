import YatimaStdLib.Matrix
import YatimaStdLib.Zmod
import Std.Data.Rat.Basic

-- TODO: We will probably want to upstream this to YSL or something

namespace Rat

def powAux (base : Rat) (exp : Nat) : Rat :=  
  let rec go (power acc : Rat) (n : Nat) : Rat :=
    match h : n with
    | 0 => acc
    | _ + 1 =>
      let n' := n / 2
      have : n' < n := Nat.bitwise_rec_lemma (h ▸ Nat.succ_ne_zero _) 
      if n % 2 == 0
      then go (power * power) acc n'
      else go (power * power) (acc * power) n'
  go base 1 exp

instance : Field Rat where
  hPow r n := powAux r n 
  coe a := { num := a, reduced := by simp only [Nat.coprime, Nat.coprime_one_right]}
  zero := 0
  one := 1
  inv x := 1/x

def abs (r : Rat) : Rat := {r with num := r.num.natAbs}

def round (r : Rat) : Int := 
  let floor := r.floor
  if abs (r - floor) ≤ (1 : Rat)/2 then floor else r.ceil

end Rat

namespace Matrix

def twoInv [Field R] (M : Matrix R) : Matrix R :=
  let det := M[0]![0]! * M[1]![1]! - M[0]![1]! * M[1]![0]!
  (Field.inv det) * #[#[M[1]![1]!, -M[0]![1]!], #[-M[1]![0]!, M[0]![0]!]]

end Matrix

namespace Zmod

instance : ToString (Zmod n) where
  toString := reprStr

end Zmod

class Random (K : Type _) where
  random {gen : Type u} [RandomGen gen] [Inhabited gen] (g : gen) : K × gen 

namespace Random

instance : Random Bool where
  random := randBool

instance [Random α] [Random β] : Random (α × β) where
  random g :=
    let (a, g) := random g
    let (b, g) := random g
    ((a, b), g)

def list (K : Type _) [Random K] {gen : Type _} [RandomGen gen] [Inhabited gen] (g : gen) (len : Nat) : List K :=
  match len with
  | 0 => []
  | n + 1 => 
    let (k, g) := random g
    k :: list K g n

def array (K : Type _) [Random K] {gen : Type _} [RandomGen gen] [Inhabited gen] (g : gen) (len : Nat) : Array K :=
  Id.run do
    let mut answer := #[]
    let mut (k, g') := random g
    for _ in [:len] do
      (k, g') := random g'
      answer := answer.push k
    
    return answer

end Random