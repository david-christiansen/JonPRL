functor CttUtil
  (structure Lcf : LCF_APART
   structure Syntax : ABT
   structure Conv : CONV
     where type term = Syntax.t
   structure Ctt : CTT
      where type tactic = Lcf.tactic
      where type conv = Conv.conv
      where type term = Syntax.t
      where type name = Syntax.Variable.t) : CTT_UTIL =
struct
  structure Lcf = Lcf
  structure Tacticals = ProgressTacticals(Lcf)
  open Conv Ctt

  structure Conversionals = Conversionals
    (structure Syntax = Syntax
     structure Conv = Conv)

  open Tacticals Rules
  infix ORELSE ORELSE_LAZY THEN

  type intro_args =
    {term : term option,
     rule : int option,
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

  fun Intro {term,rule,freshVariable,level} =
     UnitIntro
       ORELSE Assumption
       ORELSE_LAZY (fn _ => case valOf rule of
                                0 => PlusIntroL level
                              | 1 => PlusIntroR level
                              | _ => raise Fail "Out of range for PLUS")
       ORELSE FunIntro (freshVariable, level)
       ORELSE IsectIntro (freshVariable, level)
       ORELSE_LAZY (fn _ => ProdIntro (valOf term, freshVariable, level))
       ORELSE IndependentProdIntro
       ORELSE_LAZY (fn _ => SubsetIntro (valOf term, freshVariable, level))
       ORELSE IndependentSubsetIntro
       ORELSE CEqRefl
       ORELSE CEqStruct
       ORELSE BaseIntro
       ORELSE MemCD

  fun take2 (x::y::_) = SOME (x,y)
    | take2 _ = NONE

  fun take3 (x::y::z::_) = SOME (x,y,z)
    | take3 _ = NONE

  fun listAt (xs, n) = SOME (List.nth (xs, n)) handle _ => NONE

  fun Elim {target, names, term} =
    let
      val twoNames = take2 names
    in
      (VoidElim THEN Hypothesis target)
        ORELSE UnitElim target
        ORELSE_LAZY (fn _ => BaseElimEq (target, listAt (names, 0)))
        ORELSE_LAZY (fn _ => PlusElim (target, twoNames))
        ORELSE_LAZY (fn _ => ProdElim (target, twoNames))
        ORELSE_LAZY (fn _ => FunElim (target, valOf term, twoNames))
        ORELSE_LAZY (fn _ => IsectElim (target, valOf term, twoNames))
        ORELSE NatElim (target, twoNames)
        ORELSE SubsetElim (target, twoNames)
    end

  fun EqCD {names, level, terms} =
    let
      val freshVariable = listAt (names, 0)
    in
      AxEq
        ORELSE EqEq
        ORELSE CEqEq
        ORELSE UnitEq
        ORELSE VoidEq
        ORELSE HypEq
        ORELSE UnivEq
        ORELSE PlusEq
        ORELSE InlEq level
        ORELSE InrEq level
        ORELSE BaseEq
        ORELSE BaseMemberEq
        ORELSE_LAZY (fn _ => DecideEq (List.nth (terms, 0))
                                      (List.nth (terms, 1),
                                       List.nth (terms, 2),
                                       take3 names))
        ORELSE NatRecEq (listAt (terms, 0), take2 names)
        ORELSE FunEq freshVariable
        ORELSE IsectEq freshVariable
        ORELSE ProdEq freshVariable
        ORELSE SubsetEq freshVariable
        ORELSE PairEq (freshVariable, level)
        ORELSE LamEq (freshVariable, level)
        ORELSE ApEq (listAt (terms, 0))
        ORELSE SpreadEq (listAt (terms, 0), listAt (terms, 1), take3 names)
        ORELSE SubsetMemberEq (freshVariable, level)
        ORELSE IsectMemberEq (freshVariable, level)
        ORELSE_LAZY (fn _ =>
          case terms of
               [M, N] => IsectMemberCaseEq (SOME M, N)
             | [N] => IsectMemberCaseEq (NONE, N)
             | _ => FAIL)
        ORELSE NatEq
        ORELSE ZeroEq
        ORELSE SuccEq
        ORELSE Cum level
        ORELSE EqInSupertype
    end

  fun Ext {freshVariable, level} =
    FunExt (freshVariable, level)

  local
    val AutoEqCD =
      EqCD {names = [], level = NONE, terms = []}

    val AutoVoidElim = VoidElim THEN Assumption
    val AutoIntro = Intro {term = NONE,
                           rule = NONE,
                           freshVariable = NONE,
                           level = NONE}

    open Conversions Conversionals
    infix CORELSE

    val DeepReduce = RewriteGoal (CDEEP Step)
  in
    val Auto =
      LIMIT (AutoIntro ORELSE AutoVoidElim ORELSE AutoEqCD)

    fun Reduce NONE = LIMIT DeepReduce
      | Reduce (SOME n) =
        let
          fun go 0 = ID
            | go n = DeepReduce THEN (go (n - 1))
        in
          go n
        end
  end

  local
    structure Tacticals = Tacticals (Lcf)
    open Tacticals Sequent
    infix THENL >>
  in
    fun CutLemma (world, lbl) =
      let
        val {statement,...} = Ctt.Development.lookupTheorem world lbl
        val H >> P = statement
        val _ = if Context.eq (H, Context.empty) then () else raise Fail "nonempty context"
        val name = Syntax.Variable.named (Ctt.Development.Telescope.Label.toString lbl)
      in
        Assert (P, SOME name)
          THENL [Lemma (world, lbl), ID]
      end
  end

end

structure CttUtil = CttUtil
  (structure Syntax = Syntax and Lcf = Lcf and Conv = Conv and Ctt = Ctt)
