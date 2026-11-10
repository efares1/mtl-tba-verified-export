
type __ = Obj.t

val xorb : bool -> bool -> bool

type comparison =
| Eq
| Lt
| Gt

val compOpp : comparison -> comparison

module Nat :
 sig
  val divmod : int -> int -> int -> int -> int * int
 end

val remove : ('a1 -> 'a1 -> bool) -> 'a1 -> 'a1 list -> 'a1 list

val fold_left : ('a1 -> 'a2 -> 'a1) -> 'a2 list -> 'a1 -> 'a1

val find : ('a1 -> bool) -> 'a1 list -> 'a1 option

val nodup : ('a1 -> 'a1 -> bool) -> 'a1 list -> 'a1 list



module Pos :
 sig
  val succ : int -> int

  val add : int -> int -> int

  val add_carry : int -> int -> int

  val pred_double : int -> int

  type mask =
  | IsNul
  | IsPos of int
  | IsNeg

  val mul : int -> int -> int

  val compare_cont : comparison -> int -> int -> comparison

  val compare : int -> int -> comparison

  val iter_op : ('a1 -> 'a1 -> 'a1) -> int -> 'a1 -> 'a1

  val to_nat : int -> int

  val of_succ_nat : int -> int
 end

module Coq_Pos :
 sig
  val succ : int -> int

  val add : int -> int -> int

  val add_carry : int -> int -> int

  val pred_double : int -> int

  type mask = Pos.mask =
  | IsNul
  | IsPos of int
  | IsNeg

  val succ_double_mask : mask -> mask

  val double_mask : mask -> mask

  val double_pred_mask : int -> mask

  val sub_mask : int -> int -> mask

  val sub_mask_carry : int -> int -> mask

  val sub : int -> int -> int

  val mul : int -> int -> int

  val compare_cont : comparison -> int -> int -> comparison

  val compare : int -> int -> comparison

  val iter_op : ('a1 -> 'a1 -> 'a1) -> int -> 'a1 -> 'a1

  val to_nat : int -> int

  val size_nat : int -> int

  val ggcdn : int -> int -> int -> int * (int * int)

  val ggcd : int -> int -> int * (int * int)

  val of_nat : int -> int
 end

val pow_pos : ('a1 -> 'a1 -> 'a1) -> 'a1 -> int -> 'a1

module Z :
 sig
  val double : int -> int

  val succ_double : int -> int

  val pred_double : int -> int

  val pos_sub : int -> int -> int

  val add : int -> int -> int

  val opp : int -> int

  val sub : int -> int -> int

  val mul : int -> int -> int

  val compare : int -> int -> comparison

  val max : int -> int -> int

  val to_nat : int -> int

  val of_nat : int -> int

  val to_pos : int -> int

  val sgn : int -> int

  val abs : int -> int

  val ggcd : int -> int -> int * (int * int)
 end

val z_lt_dec : int -> int -> bool

val z_lt_ge_dec : int -> int -> bool

val z_lt_le_dec : int -> int -> bool

type q = { qnum : int; qden : int }

val qplus : q -> q -> q

val qmult : q -> q -> q

val qopp : q -> q

val qminus : q -> q -> q

val qinv : q -> q

val qlt_le_dec : q -> q -> bool

val qarchimedean : q -> int

val qpower_positive : q -> int -> q

val qpower : q -> int -> q

val qabs : q -> q

val pos_log2floor_plus1 : int -> int

val qbound_lt_ZExp2 : q -> int

type cReal = { seq : (int -> q); scale : int }

val sig_forall_dec : (int -> bool) -> int option

val lowerCutBelow : (q -> bool) -> q

val lowerCutAbove : (q -> bool) -> q

type dReal = (q -> bool)

val dRealQlim_rec : (q -> bool) -> int -> int -> q

val dRealAbstr : cReal -> dReal

val dRealQlim : dReal -> int -> q

val dRealQlimExp2 : dReal -> int -> q

val cReal_of_DReal_seq : dReal -> int -> q

val cReal_of_DReal_scale : dReal -> int

val dRealRepr : dReal -> cReal

module type RbaseSymbolsSig =
 sig
  type coq_R

  val coq_Rabst : cReal -> coq_R

  val coq_Rrepr : coq_R -> cReal

  val coq_R0 : coq_R

  val coq_R1 : coq_R

  val coq_Rplus : coq_R -> coq_R -> coq_R

  val coq_Rmult : coq_R -> coq_R -> coq_R

  val coq_Ropp : coq_R -> coq_R
 end

module RbaseSymbolsImpl :
 RbaseSymbolsSig



type action = int

type path = bool list

val left_path : path -> path

val right_path : path -> path

type mtl =
| MTrue
| MFalse
| MAtom of action
| MNotAtom of action
| MAnd of mtl * mtl
| MOr of mtl * mtl
| MNext of mtl
| MU of mtl * mtl
| MR of mtl * mtl
| MUhatLe of float * mtl * mtl
| MUhatGe of float * mtl * mtl
| MRhatLe of float * mtl * mtl
| MRhatGe of float * mtl * mtl
| MUhatLt of float * mtl * mtl
| MUhatGt of float * mtl * mtl
| MRhatLt of float * mtl * mtl
| MRhatGt of float * mtl * mtl

val mUle : float -> mtl -> mtl -> mtl

val mUge : float -> mtl -> mtl -> mtl

val mRle : float -> mtl -> mtl -> mtl

val mRge : float -> mtl -> mtl -> mtl

val mUlt : float -> mtl -> mtl -> mtl

val mUgt : float -> mtl -> mtl -> mtl

val mRlt : float -> mtl -> mtl -> mtl

val mRgt : float -> mtl -> mtl -> mtl

val timed_subformulas : mtl -> mtl list

type clock = mtl

val mtl_eq_dec : mtl -> mtl -> bool

val clock_eq_dec : mtl -> clock -> clock -> bool

val clock_of : mtl -> mtl -> clock option

type latom =
| LAct of action
| LNAct of action
| LCLe of clock * float
| LCLt of clock * float
| LCGe of clock * float
| LCGt of clock * float
| LRst of clock
| LUnch of clock

type ltl =
| LTrue
| LFalse
| LAtom of latom
| LAnd of ltl * ltl
| LOr of ltl * ltl
| LNext of ltl
| LUntil of ltl * ltl
| LRelease of ltl * ltl

val lF : mtl -> ltl -> ltl

val lG : mtl -> ltl -> ltl

val lW : mtl -> ltl -> ltl -> ltl

val lGF : mtl -> ltl -> ltl

val t_at : mtl -> path -> mtl -> ltl

type alit = action * bool

val ltl_atoms : mtl -> ltl -> latom list

type plit = latom * bool

type ptransition = { pt_src : int; pt_label : plit list; pt_tgt : int }

type pBuchi = { pb_nstates : int; pb_init : int; pb_trans : ptransition list;
                pb_accepting : int list }

type clock_comparison =
| CLe
| CLt
| CGe
| CGt
| CEq

type clock_constraint = { guard_clock : clock;
                          guard_comparison : clock_comparison;
                          guard_bound : float }

type guard = clock_constraint option list

val atom_to_guard : mtl -> latom -> clock_constraint option

type tba_transition = { bt_source : int; bt_label : alit list;
                        bt_guard : guard; bt_resets : clock list;
                        bt_target : int }

type tBA = { tba_nstates : int; tba_init : int;
             tba_transitions : tba_transition list; tba_accepting : int list }

val t : mtl -> ltl

val latom_eq_dec : mtl -> latom -> latom -> bool

val latom_eqb : mtl -> latom -> latom -> bool

val in_atoms : mtl -> latom -> latom list -> bool

val is_ext : mtl -> latom -> bool

val lit_conflict : mtl -> plit -> plit -> bool

val consistent : mtl -> plit list -> bool

val keep_lit : mtl -> latom list -> plit -> bool

val relax_trans : mtl -> latom list -> ptransition -> ptransition

val relax : mtl -> latom list -> pBuchi -> pBuchi

val is_restart : mtl -> clock -> bool

val all_clocks : mtl -> clock list

val has_pos : mtl -> latom -> plit list -> bool

val comp_resets : mtl -> plit list -> clock list

val act_lit : mtl -> plit -> alit list

val pos_atoms : mtl -> plit list -> latom list

val complete_trans : mtl -> ptransition -> tba_transition

val complete : mtl -> pBuchi -> tBA

val compile_with : mtl -> pBuchi -> tBA

val is_upper : clock_comparison -> bool

val clock_eqb : mtl -> clock -> clock -> bool

val opt_min : float option -> float option -> float option

val ub_item : mtl -> clock -> clock_constraint option -> float option

val ub_guard : mtl -> guard -> clock -> float option

val max_all : float option list -> float option

val outgoing : mtl -> tBA -> int -> tba_transition list

val synth_inv : mtl -> tBA -> int -> clock -> float option

type invariant = clock -> float option

val upper_clocks : mtl -> clock_constraint option -> clock list

val implies_c : mtl -> clock_constraint -> clock_constraint -> bool

val insert_t :
  mtl -> clock_constraint -> clock_constraint list -> clock_constraint list

val present : mtl -> guard -> clock_constraint list

val tighten : mtl -> guard -> guard

val conj_guard : mtl -> guard -> guard -> guard

val with_transitions : mtl -> tBA -> tba_transition list -> tBA

val is_lower : clock_comparison -> bool

val opt_max : float option -> float option -> float option

val lb_item : mtl -> clock -> clock_constraint option -> float option

val lb_guard : mtl -> guard -> clock -> float option

val min_all : float option list -> float option

val incoming : mtl -> tBA -> int -> tba_transition list

val entry_bound : mtl -> tba_transition -> clock -> float option

val entry_lb : mtl -> tBA -> int -> clock -> float option

val lower_clocks : mtl -> clock_constraint option -> clock list

val entry_clocks : mtl -> tBA -> int -> clock list

type tBAIL = { tbail_base : tBA; tbail_up : (int -> invariant);
               tbail_low : (int -> invariant) }

val add_two_sided_invariants : mtl -> tBA -> tBAIL

val lower_info :
  mtl -> clock_constraint option -> ((clock * float) * bool) option

val upper_info :
  mtl -> clock_constraint option -> ((clock * float) * bool) option

val contradictory_bounds : float -> bool -> float -> bool -> bool

val contra_pair :
  mtl -> clock_constraint option -> clock_constraint option -> bool

val negative_upper : mtl -> clock_constraint option -> bool

val guard_contradictory : mtl -> guard -> bool

val remove_contradictory : mtl -> tBA -> tBA

val has_incoming : mtl -> tBA -> int -> bool

val remove_unreachable : mtl -> tBA -> tBA

val label_sat : alit list -> bool

val remove_unsat : mtl -> tBA -> tBA

val rename_item :
  mtl -> clock -> clock -> clock_constraint option -> clock_constraint option

val merge_transition :
  mtl -> clock -> clock -> tba_transition -> tba_transition

val merge_clock : mtl -> clock -> clock -> tBA -> tBA

val mentions : mtl -> clock -> clock_constraint option -> bool

val clock_in : mtl -> clock -> clock list -> bool

val mergeable_b : mtl -> tBA -> clock -> clock -> bool

val try_merge : mtl -> clock -> clock -> tBA -> tBA

val merge_pairs : mtl -> (clock * clock) list -> tBA -> tBA

val reset_clocks : mtl -> tBA -> clock list

val merge_all : mtl -> tBA -> tBA

val tests : mtl -> clock -> tba_transition -> bool

val live_step : mtl -> tBA -> clock -> int list -> int list

val live_iter : mtl -> int -> tBA -> clock -> int list -> int list

val live : mtl -> tBA -> clock -> int list

val drop_reset : mtl -> clock -> tba_transition -> tba_transition

val remove_dead_resets_clock_fast : mtl -> clock -> tBA -> tBA

val remove_dead_resets_list : mtl -> clock list -> tBA -> tBA

val remove_dead_resets : mtl -> tBA -> tBA

val trivial_c : mtl -> clock_constraint -> bool

val insert_c :
  mtl -> clock_constraint -> clock_constraint list -> clock_constraint list

val norm_guard : mtl -> guard -> guard

val normalize_transition : mtl -> tba_transition -> tba_transition

val normalize : mtl -> tBA -> tBA

val alit_dec : alit -> alit -> bool

val cmp_dec : clock_comparison -> clock_comparison -> bool

val cc_dec : mtl -> clock_constraint -> clock_constraint -> bool

val item_dec :
  mtl -> clock_constraint option -> clock_constraint option -> bool

val tr_dec : mtl -> tba_transition -> tba_transition -> bool

val beq : ('a1 -> 'a1 -> bool) -> 'a1 -> 'a1 -> bool

val set_incl : ('a1 -> 'a1 -> bool) -> 'a1 list -> 'a1 list -> bool

val set_eqb : ('a1 -> 'a1 -> bool) -> 'a1 list -> 'a1 list -> bool

val free_loop : mtl -> int -> clock -> tba_transition -> bool

val entry_lb_loop : mtl -> tBA -> int -> clock -> float option

val entry_guard_loop : mtl -> tBA -> int -> guard

val red : int -> int -> int -> int

val redirect : mtl -> int -> int -> tba_transition -> tba_transition

val guard_implied : mtl -> guard -> guard -> bool

val sim :
  mtl -> int -> int -> guard -> tba_transition -> tba_transition -> bool

val in_nat : int -> int list -> bool

val covers_fast : mtl -> tBA -> int -> int -> guard -> int -> int -> bool

val states_mergeable_fast : mtl -> tBA -> int -> int -> bool

val merge_states : mtl -> int -> int -> tBA -> tBA

val try_merge_states : mtl -> int -> int -> tBA -> tBA

val state_pairs : int -> (int * int) list

val merge_states_all : mtl -> tBA -> tBA

val same_ends : mtl -> tba_transition -> tba_transition -> bool

val subsumes : mtl -> tba_transition -> tba_transition -> bool

val insert_sub :
  mtl -> tba_transition -> tba_transition list -> tba_transition list

val remove_item : ('a1 -> 'a1 -> bool) -> 'a1 -> 'a1 list -> 'a1 list

val neg_alit : alit -> alit

val resolve_lab : alit list -> alit list -> alit list option

val compl : mtl -> clock_constraint -> clock_constraint option

val resolve_grd : mtl -> guard -> guard -> guard option

val with_label : mtl -> tba_transition -> alit list -> tba_transition

val with_guard : mtl -> tba_transition -> guard -> tba_transition

val resolve : mtl -> tba_transition -> tba_transition -> tba_transition option

val insert_res :
  mtl -> tba_transition -> tba_transition list -> tba_transition list

val merge_trans : mtl -> tBA -> tBA

val table_of : mtl -> (int -> 'a1) -> tBA -> 'a1 list

val lookup : mtl -> 'a1 -> (int -> 'a1) -> 'a1 list -> tBA -> int -> 'a1

val entry_clocks_w : mtl -> (int -> tba_transition list) -> int -> clock list

val entry_lb_w :
  mtl -> tBA -> (int -> tba_transition list) -> int -> clock -> float option

val entry_guard_w : mtl -> tBA -> (int -> tba_transition list) -> int -> guard

val forward_fast : mtl -> tBA -> tBA

val synth_inv_w :
  mtl -> (int -> tba_transition list) -> int -> clock -> float option

val inv_clocks_w : mtl -> (int -> tba_transition list) -> int -> clock list

val inv_item_of :
  mtl -> clock list -> clock -> float option -> clock_constraint option

val inv_info_w :
  mtl -> (int -> tba_transition list) -> int -> (clock * float option) list

val inv_guard_of_info :
  mtl -> clock list -> (clock * float option) list -> guard

val propagate_fast : mtl -> tBA -> tBA

val optimize_step : mtl -> tBA -> tBA

val optimize : mtl -> int -> tBA -> tBA

val optimized : mtl -> int -> tBA -> tBAIL

val complete_fast : mtl -> pBuchi -> tBA

val compile_with_fast : mtl -> pBuchi -> tBA

type dconstraint =
| DSingle of clock_constraint
| DDiff of clock * clock * float

type dconj = dconstraint list

type dguard = dconj list

type uinv = (clock * float) list

type dtrans = { dt_src : int; dt_label : alit list; dt_guard : dguard;
                dt_resets : clock list; dt_tgt : int }

type dTA = { dta_nstates : int; dta_init : int; dta_trans : dtrans list;
             dta_accepting : int list; dta_inv : (int -> uinv list option) }

val singles : mtl -> guard -> dconj

val of_tba_trans : mtl -> tba_transition -> dtrans

val of_tba : mtl -> tBA -> dTA

val alit_eq_dec : alit -> alit -> bool

val same_key_dec : mtl -> dtrans -> dtrans -> bool

val add_guard : mtl -> dtrans -> dguard -> dtrans

val insert_trans : mtl -> dtrans -> dtrans list -> dtrans list

val group : mtl -> dtrans list -> dtrans list

val merge_transitions : mtl -> dTA -> dTA

val ub_conj : mtl -> dconj -> uinv

val outgoing_d : mtl -> dTA -> int -> dtrans list

val uimplies : mtl -> uinv -> uinv -> bool

val insert_u : mtl -> uinv -> uinv list -> uinv list

val dedupe_u : mtl -> uinv list -> uinv list

val disj_inv : mtl -> dTA -> int -> uinv list

val upper_singles : mtl -> uinv -> dconj

val notlonger : mtl -> uinv -> uinv -> dguard

val dnf_and : mtl -> dguard -> dguard -> dguard

val notlonger_all : mtl -> uinv list -> uinv -> dguard

val entry_cond : mtl -> uinv list -> int -> dguard

val const_true : mtl -> clock_constraint -> bool

val subst_c : mtl -> clock list -> dconstraint -> dconj option

val subst_conj : mtl -> clock list -> dconj -> dconj option

val subst_guard : mtl -> clock list -> dguard -> dguard

val kmax : mtl -> dTA -> int

val kp : mtl -> dTA -> int

val enc : mtl -> dTA -> int -> int -> int

val split_inv : mtl -> dTA -> int -> uinv list option

val split_all_trans : mtl -> dTA -> dtrans -> dtrans list

val split_all : mtl -> dTA -> dTA

val explode : mtl -> dtrans -> dtrans list

val explode_all : mtl -> dTA -> dTA

val implies_d : mtl -> dconstraint -> dconstraint -> bool

val trivial_d : mtl -> dconstraint -> bool

val self_contra : mtl -> dconstraint -> bool

val insert_d : mtl -> dconstraint -> dconj -> dconj

val dnorm_conj : mtl -> dconj -> dconj

val conj_implies : mtl -> dconj -> dconj -> bool

val insert_g : mtl -> dconj -> dguard -> dguard

val dnorm_guard : mtl -> dguard -> dguard

val normalize_dtrans : mtl -> dtrans -> dtrans

val normalize_d : mtl -> dTA -> dTA

val dhas_incoming : mtl -> dTA -> int -> bool

val dprune : mtl -> dTA -> dTA

val dprune_n : mtl -> int -> dTA -> dTA

val dprune_all : mtl -> dTA -> dTA

val dc_dec : mtl -> dconstraint -> dconstraint -> bool

val dconj_dec : mtl -> dconj -> dconj -> bool

val cr_dec : mtl -> (clock * float) -> (clock * float) -> bool

val oinv_dec : mtl -> uinv list option -> uinv list option -> bool

val inv_norm : mtl -> uinv list option -> uinv list option

val dred_trans : mtl -> int -> int -> dtrans -> dtrans

val dsim : mtl -> int -> int -> dtrans -> dtrans -> bool

val dout : mtl -> dTA -> int -> dtrans list

val dcovers : mtl -> dTA -> int -> int -> int -> int -> bool

val dstates_mergeable : mtl -> dTA -> int -> int -> bool

val dmerge_states : mtl -> int -> int -> dTA -> dTA

val dtry_merge_states : mtl -> int -> int -> dTA -> dTA

val dmerge_states_all : mtl -> dTA -> dTA

val table_n : int -> (int -> 'a1) -> 'a1 list

val lookup_n : int -> 'a1 -> (int -> 'a1) -> 'a1 list -> int -> 'a1

val enc_w : int -> int -> int -> int

val split_trans_w : mtl -> int -> (int -> uinv list) -> dtrans -> dtrans list

val split_inv_w :
  mtl -> int -> int -> (int -> uinv list) -> int -> uinv list option

val split_w : mtl -> int -> int -> (int -> uinv list) -> dTA -> dTA

val kmax_w : mtl -> (int -> uinv list) -> dTA -> int

val split_fast : mtl -> dTA -> dTA

val export : mtl -> tBA -> dTA

val export_all : mtl -> tBA -> dTA

val dc_clocks : mtl -> dconstraint -> clock list

val trans_reads : mtl -> dtrans -> clock list

val inv_reads : mtl -> uinv list option -> clock list

val mem_clock : mtl -> clock -> clock list -> bool

val inv_table : mtl -> dTA -> clock list list

val live0 : mtl -> dTA -> clock list list -> clock -> int list

val live_step0 : mtl -> dTA -> clock -> int list -> int list -> int list

val live_search :
  mtl -> dTA -> clock -> int -> int list -> int list -> int list

val live_set : mtl -> dTA -> clock list list -> clock -> int list

val live_ok : mtl -> dTA -> clock list list -> clock -> int list -> bool

val init_free : mtl -> dTA -> bool

val s_and : mtl -> ltl -> ltl -> ltl

val s_or : mtl -> ltl -> ltl -> ltl

val s_next : mtl -> ltl -> ltl

val s_until : mtl -> ltl -> ltl -> ltl

val s_release : mtl -> ltl -> ltl -> ltl

val ltl_simp : mtl -> ltl -> ltl

type evset =
| EvIn of action list
| EvOut of action list

val memb : action -> action list -> bool

val meet : evset -> alit -> evset

val evset_of_label : alit list -> evset

val ev_union : evset -> evset -> evset

type scase = evset * dconj

type strans = { st_src : int; st_resets : clock list; st_tgt : int;
                st_cases : scase list }

type sDTA = { sdta_nstates : int; sdta_init : int; sdta_trans : strans list;
              sdta_accepting : int list; sdta_inv : (int -> uinv list option) }

val add_case : mtl -> scase -> scase list -> scase list

val add_cases : mtl -> scase list -> scase list -> scase list

val cases_of : mtl -> dtrans -> scase list

val same_skey : mtl -> strans -> dtrans -> bool

val ins : mtl -> dtrans -> strans list -> strans list

val group0 : mtl -> dtrans list -> strans list

val symbolic : mtl -> dTA -> sDTA

val neg : mtl -> mtl

val upper_wait : mtl -> ltl -> bool

val weak : mtl -> ltl -> ltl

val is_true : mtl -> bool

val is_false : mtl -> bool

val rw1 : mtl -> mtl

val recur : mtl -> mtl

val optimize_export : mtl -> int -> tBA -> dTA

val optimize_export_all : mtl -> int -> tBA -> dTA
