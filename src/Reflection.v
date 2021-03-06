(** * Proof by reflection **)

(** The idea of proof by reflection is to prove a class of theorems using
certified decision procedures, that is, Coq functions that have a theorem
showing their correctness. *)

(** ** Overview **)

(** Reflection applies to small, self-contained cases of using decision
procedures. However, in practice, the most common way to use reflection is both
more involved and follows a common structure:
- 1. Write down the syntax of the expressions you want to prove something about,
  say in an inductive type [term].
- 2. Interpret the terms back into what they represent, say [denote : term -> A].
  The type [A] might be a different expression or directly a [Prop].
- 3. Implement some procedure over terms; maybe [simplifier: term -> term] or
  [check: term -> bool].
- 4. Prove a soundness property of this procedure over what the terms denote,
  maybe [forall t, equivalent t (simplifier t)] or [forall t, check t = true -> denote t].
- 5. Reify the target language [A] into [term]. Typically this is implemented in
  Ltac since we need to turn calls like [add x y] into a constructor, which can't
  be implemented in Gallina.

This step is occasionally called "reflection", though "reification" is a clearer
term since "relection" can refer to the whole approach or just the use of a
certified decision procedure.

Now, given a goal that uses the target language (here values of type [A]), the
user can use reification to produce a term [t], then apply the soundness
property to get some proof about [denote t], which after simplification will be
a proof about some [a:A] that appears in the goal. *)

(** ** A motivating example **)

(** The best way to understand proof by reflection is to look at an example.
We'll use reflection to normalize an addition expression. *)

Require Import Coq.Arith.PeanoNat.

Inductive term :=
| Const (n:nat)
| Add (e1 e2:term).

Fixpoint denote (t:term) : nat :=
  match t with
  | Const n => n
  | Add e1 e2 => denote e1 + denote e2
  end.

Fixpoint flatten (x0:term) (t:term) : term :=
  match t with
  | Const n => Add x0 (Const n)
  | Add e1 e2 => flatten (flatten x0 e1) e2
  end.

Eval cbn [denote flatten] in
    fun x y z w => denote (flatten (Const 0)
                                (Add (Add (Const x) (Const y))
                                     (Add (Const z) (Const w)))).

(* the property we'll prove is that flattening does not change the denotation of
a term; to do so we need to first prove a more general property to get the
induction to go through *)

Theorem flatten_sound_general t : forall x,
  denote (flatten x t) = denote x + denote t.
Proof.
  induction t; simpl; intros; auto.
  rewrite IHt2, IHt1.
  rewrite Nat.add_assoc; auto.
Qed.

Theorem flatten_sound t :
  denote t = denote (flatten (Const 0) t).
Proof.
  rewrite flatten_sound_general; simpl; auto.
Qed.

Ltac reify e :=
  match e with
  | ?x + ?y =>
    let r_x := reify x in
    let r_y := reify y in
    constr:(Add r_x r_y)
  | _ => constr:(Const e)
  end.

Theorem demo x y z :
  x + (y + z) = x + y + z.
Proof.
  match goal with
  | |- ?e = ?e' => let t := reify e in
                 let t' := reify e' in
                 change (denote t = denote t')
  end.
  match goal with
  | |- denote ?t = denote ?t' =>
    rewrite (flatten_sound t), (flatten_sound t')
  end.
  (* this is where the magic becomes apparent: the soundness theorem applies to
  any term, but flatten computes to a particular expression when applied to
  these concrete terms *)
  cbn [denote flatten].
  reflexivity.
Qed.

(* we can wrap up the process of simplifying expressions in a tactic *)
Ltac canonical_assoc e :=
  let t := reify e in
  change e with (denote t);
  rewrite (flatten_sound t);
  cbn [denote flatten].

Theorem larger_demo x y z w :
  x + (y + z + w) + x + (y + z) =
  x + (y + z) + (w + (x + y)) + z.
Proof.
  match goal with
  | |- ?e = ?e' => canonical_assoc e;
                   canonical_assoc e'
  end.
  reflexivity.
Qed.

(** ** Why use reflection? **)

(** Reflection offers a number of benefits.

I think the most important aspect of reflection is robustness. A reflective
tactic defines an explicit syntax for the goals it handles and then implements
the rest of the work in a certified decision procedure. Now instead of reasoning
about what some Ltac procedure might do, you can just focus on what the
soundness theorem says. In some cases the certified procedure is partial (that
is, it might fail and not prove anything); in these cases you might also want to
check to see where it fails.

*)

(** ** A more abstract introduction **)

(** Computational reflection is a technique for proving theorems using
computation in the meta-language (that is, computation in Coq), as opposed to
building a proof term using only logical rules (eg, constructors in an inductive
type).

It relies on the conversion rule of dependent theory:

<<
x : A    A ≡ B
------------- conv
    x : B
>>

The judgement A ≡ B is where the magic happens: in dependent type theory, this
equivalence allows _computation_, and so this rule is what allows type-checking
to simplify computations appearing in types. *)

(** For example, we can write the following in Coq: *)
Definition bool_or_nat : bool :=
  (fun x => match x return (if x then bool else nat) with
         | true => x
         | false => 0
         end) true.

(** the type of the right-hand side is [if true then bool else nat], but Coq
simplifies this expression and can also give it the type bool *)

(** Recall that Coq propositions are types and the proof of a proposition P is a
term (pf:P) (this is the Curry-Howard isomorphism). In that light, we can use
the conv rule with theorem statements that are computed. This is what proof by
reflection is.

 I believe the "reflection" is reflection of the desired proof into the
 computation, but I must confess I'm not sure what the original intention is and
 it's possible the writing on proof by reflection has gotten confused over time.
 *)
