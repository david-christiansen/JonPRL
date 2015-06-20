functor CttUtil
  (structure Lcf : LCF_APART
   structure Ctt : CTT where Lcf = Lcf) : CTT_UTIL =
struct
  structure Lcf = Lcf
  structure Tacticals = ProgressTacticals(Lcf)
  open Ctt Ctt.Conv

  structure Conversionals = Conversionals
    (structure Syntax = Syntax
     structure Conv = Conv)

  open Tacticals Rules
  infix ORELSE ORELSE_LAZY THEN

  type intro_args =
    {term : term option,
     freshVariable : name option,
     level : Level.t option}

  type elim_args =
    {target : int,
     names : name list,
     term : term option}

  type eq_cd_args =
    {names : name list,
     level : Level.t option,
     terms : term list}

  type ext_args =
    {freshVariable : name option,
     level : Level.t option}

  fun Intro {term,freshVariable,level} =
     MemCD
       ORELSE UnitIntro
       ORELSE Assumption
       ORELSE FunIntro (freshVariable, level)
       ORELSE IsectIntro (freshVariable, level)
       ORELSE_LAZY (fn _ => ProdIntro (valOf term, freshVariable, level))
       ORELSE IndependentProdIntro
       ORELSE_LAZY (fn _ => SubsetIntro (valOf term, freshVariable, level))
       ORELSE IndependentSubsetIntro

  fun take2 (x::y::_) = SOME (x,y)
    | take2 _ = NONE

  fun take3 (x::y::z::_) = SOME (x,y,z)
    | take3 _ = NONE

  fun list_at (xs, n) = SOME (List.nth (xs, n)) handle _ => NONE

  fun Elim {target, names, term} =
    (VoidElim THEN Hypothesis target)
      ORELSE UnitElim target
      ORELSE ProdElim (target, take2 names)
      ORELSE_LAZY (fn _ => FunElim (target, valOf term, take2 names))
      ORELSE_LAZY (fn _ => IsectElim (target, valOf term, take2 names))
      ORELSE SubsetElim (target, take2 names)

  fun EqCD {names, level, terms} =
    let
      val freshVariable = list_at (names, 0)
    in
      AxEq
        ORELSE EqEq
        ORELSE UnitEq
        ORELSE VoidEq
        ORELSE HypEq
        ORELSE UnivEq
        ORELSE FunEq freshVariable
        ORELSE IsectEq freshVariable
        ORELSE ProdEq freshVariable
        ORELSE SubsetEq freshVariable
        ORELSE PairEq (freshVariable, level)
        ORELSE LamEq (freshVariable, level)
        ORELSE ApEq (list_at (terms, 0))
        ORELSE SpreadEq (list_at (terms, 0), list_at (terms, 1), take3 names)
        ORELSE SubsetMemberEq (freshVariable, level)
        ORELSE IsectMemberEq (freshVariable, level)
        ORELSE_LAZY (fn _ =>
          case terms of
               [M, N] => IsectMemberCaseEq (SOME M, N)
             | [N] => IsectMemberCaseEq (NONE, N)
             | _ => FAIL)
        ORELSE Cum level
        ORELSE EqInSupertype
    end

  fun Ext {freshVariable, level} =
    FunExt (freshVariable, level)

  local
    val AutoEqCD =
      EqCD {names = [], level = NONE, terms = []}

    val AutoVoidElim = VoidElim THEN Assumption
    val AutoIntro = Intro {term = NONE, freshVariable = NONE, level = NONE}

    open Conversions Conversionals
    infix CORELSE

    val Reduce = ApBeta CORELSE SpreadBeta
    val DeepReduce = RewriteGoal (CDEEP Reduce)
  in
    val Auto =
      LIMIT (AutoIntro ORELSE AutoVoidElim ORELSE AutoEqCD ORELSE PROGRESS DeepReduce)
  end
end

structure CttUtil = CttUtil
  (structure Lcf = Lcf and Ctt = Ctt)
