(* Reader for the LBTT automata produced by Spot (ltl2tgba --lbtt).

   Unlike the parser of the prototype, it keeps the literals of Spot
   exactly as they are: a negated atom stays a negative literal, so that the
   automaton given to the verified reset completion is the automaton of
   Spot.  Guards are turned into disjunctive normal form; each cube becomes
   one transition. *)

type form =
  | T
  | F
  | Atom of string
  | Not of form
  | And of form * form
  | Or of form * form

type transition = {
  src : int;
  dst : int;
  marked : bool;                     (* carries an acceptance mark *)
  cubes : (string * bool) list list; (* disjunction of cubes of literals *)
}

type automaton = {
  nstates : int;
  init : int;
  trans : transition list;
  accepting : int list;              (* state-based acceptance, if any *)
  trans_based : bool;
}

(* ------------------------------------------------------------------ *)
(* Tokens                                                              *)

type token = Int of int | Str of string | Sym of string

let tokenize (s : string) : token list =
  let n = String.length s in
  let rec go i acc =
    if i >= n then List.rev acc
    else
      match s.[i] with
      | ' ' | '\t' | '\n' | '\r' -> go (i + 1) acc
      | '"' ->
        let j = String.index_from s (i + 1) '"' in
        go (j + 1) (Str (String.sub s (i + 1) (j - i - 1)) :: acc)
      | _ ->
        let j = ref i in
        while !j < n && not (List.mem s.[!j] [' '; '\t'; '\n'; '\r'; '"']) do incr j done;
        let w = String.sub s i (!j - i) in
        let tok = match int_of_string_opt w with Some k -> Int k | None -> Sym w in
        go !j (tok :: acc)
  in
  go 0 []

(* ------------------------------------------------------------------ *)
(* Guards (prefix notation)                                            *)

let rec parse_form = function
  | Sym "t" :: r -> (T, r)
  | Sym "f" :: r -> (F, r)
  | Str a :: r -> (Atom a, r)
  | Sym a :: r when not (List.mem a [ "!"; "&"; "|"; "i"; "e"; "^" ]) ->
    (* Spot writes the atoms that are plain identifiers without quotes *)
    (Atom a, r)
  | Sym "!" :: r -> let (p, r) = parse_form r in (Not p, r)
  | Sym ("&" | "|" | "i" | "e" | "^" as op) :: r ->
    let (p, r) = parse_form r in
    let (q, r) = parse_form r in
    let f = match op with
      | "&" -> And (p, q)
      | "|" -> Or (p, q)
      | "i" -> Or (Not p, q)
      | "e" -> Or (And (p, q), And (Not p, Not q))
      | _ -> Or (And (p, Not q), And (Not p, q)) in
    (f, r)
  | _ -> failwith "LBTT: malformed guard"

(* Disjunctive normal form, literals as (atom, polarity). *)
let rec dnf pos = function
  | T -> if pos then [ [] ] else []
  | F -> if pos then [] else [ [] ]
  | Atom a -> [ [ (a, pos) ] ]
  | Not p -> dnf (not pos) p
  | And (p, q) when pos -> conj (dnf true p) (dnf true q)
  | Or (p, q) when pos -> dnf true p @ dnf true q
  | And (p, q) -> dnf false p @ dnf false q
  | Or (p, q) -> conj (dnf false p) (dnf false q)
and conj g1 g2 = List.concat_map (fun c1 -> List.map (fun c2 -> c1 @ c2) g2) g1

(* ------------------------------------------------------------------ *)
(* Automaton                                                           *)

let parse (text : string) : automaton =
  let header = match tokenize text with
    | Int n :: Sym kind :: rest -> Some (n, String.contains kind 't', rest)
    | Int n :: Int _ :: rest -> Some (n, false, rest)
    | _ -> None in
  match header with
  | Some (nstates, trans_based, rest) ->
    let init = ref (-1) and acc = ref [] and trans = ref [] in
    let rec states k toks =
      if k = 0 then ()
      else
        match toks with
        | Int s :: Int i :: r ->
          if i = 1 then init := s;
          (* state-based acceptance sets *)
          let rec accs r = match r with
            | Int (-1) :: r -> r
            | Int _ :: r -> acc := s :: !acc; accs r
            | _ -> r in
          let r = if trans_based then r else accs r in
          let rec trs r = match r with
            | Int (-1) :: r -> r
            | Int d :: r ->
              let rec marks m r = match r with
                | Int (-1) :: r -> (m, r)
                | Int _ :: r -> marks true r
                | _ -> failwith "LBTT: malformed transition" in
              let (m, r) = marks false r in
              let (g, r) = parse_form r in
              trans := { src = s; dst = d; marked = m; cubes = dnf true g } :: !trans;
              trs r
            | _ -> failwith "LBTT: malformed transition list" in
          states (k - 1) (trs r)
        | _ -> failwith "LBTT: malformed state" in
    states nstates rest;
    { nstates; init = !init; trans = List.rev !trans;
      accepting = List.sort_uniq compare !acc; trans_based }
  | _ -> failwith "LBTT: malformed header"

(* ------------------------------------------------------------------ *)
(* HOA (Spot's --hoa), state-based Buchi acceptance                    *)

(* The guards of the edges are Boolean formulas over the atomic
   propositions numbered in the header; they are expanded into cubes by the
   same [dnf] as the LBTT guards. *)
let parse_hoa (text : string) : automaton =
  let n = String.length text in
  let fail m = failwith ("HOA: " ^ m) in
  let aps = ref [||] and nstates = ref (-1) and init = ref (-1) in
  let all_acc = ref false in
  (* position just after --BODY-- *)
  let body =
    let key = "--BODY--" in
    let kl = String.length key in
    let rec find i =
      if i + kl > n then fail "no body"
      else if String.sub text i kl = key then i + kl else find (i + 1) in
    find 0 in
  let header = String.sub text 0 body in
  List.iter (fun line ->
      let line = String.trim line in
      let after k = String.trim (String.sub line (String.length k) (String.length line - String.length k)) in
      let starts k = String.length line >= String.length k && String.sub line 0 (String.length k) = k in
      if starts "States:" then nstates := int_of_string (after "States:")
      else if starts "Start:" then init := int_of_string (after "Start:")
      else if starts "AP:" then begin
        (* AP: k "a" "b" ... *)
        let rest = after "AP:" in
        let names = ref [] and i = ref 0 and m = String.length rest in
        while !i < m do
          if rest.[!i] = '"' then begin
            let j = String.index_from rest (!i + 1) '"' in
            names := String.sub rest (!i + 1) (j - !i - 1) :: !names;
            i := j + 1
          end else incr i
        done;
        aps := Array.of_list (List.rev !names)
      end
      else if starts "Acceptance:" then begin
        let a = after "Acceptance:" in
        if a = "0 t" then all_acc := true
        else if a <> "1 Inf(0)" then fail ("unsupported acceptance condition " ^ a)
      end)
    (String.split_on_char '\n' header);
  if !nstates < 0 || !init < 0 then fail "missing States or Start";
  (* body *)
  let pos = ref body in
  let peek () = if !pos < n then text.[!pos] else '\000' in
  let skip_ws () = while !pos < n && (match text.[!pos] with ' ' | '\t' | '\n' | '\r' -> true | _ -> false) do incr pos done in
  let read_int () =
    skip_ws ();
    let s = !pos in
    while !pos < n && text.[!pos] >= '0' && text.[!pos] <= '9' do incr pos done;
    if s = !pos then fail "integer expected";
    int_of_string (String.sub text s (!pos - s)) in
  let looking_at k = !pos + String.length k <= n && String.sub text !pos (String.length k) = k in
  let rec expr () =
    let t = term () in
    skip_ws ();
    if peek () = '|' then (incr pos; Or (t, expr ())) else t
  and term () =
    let f = factor () in
    skip_ws ();
    if peek () = '&' then (incr pos; And (f, term ())) else f
  and factor () =
    skip_ws ();
    match peek () with
    | '!' -> incr pos; Not (factor ())
    | '(' -> incr pos; let e = expr () in skip_ws (); if peek () <> ')' then fail "')' expected"; incr pos; e
    | 't' -> incr pos; T
    | 'f' -> incr pos; F
    | c when c >= '0' && c <= '9' ->
      let k = read_int () in
      if k >= Array.length !aps then fail "unknown atomic proposition";
      Atom !aps.(k)
    | _ -> fail "malformed label" in
  (* optional {marks} : true if it contains a mark *)
  let marks () =
    skip_ws ();
    if peek () = '{' then begin
      let j = String.index_from text !pos '}' in
      let inner = String.trim (String.sub text (!pos + 1) (j - !pos - 1)) in
      pos := j + 1; inner <> ""
    end else false in
  let acc = ref [] and trans = ref [] in
  let cur = ref (-1) in
  let fin = ref false in
  while not !fin do
    skip_ws ();
    if looking_at "--END--" || !pos >= n then fin := true
    else if looking_at "State:" then begin
      pos := !pos + 6;
      let s = read_int () in
      cur := s;
      skip_ws ();
      if peek () = '"' then (let j = String.index_from text (!pos + 1) '"' in pos := j + 1);
      if marks () then acc := s :: !acc
    end
    else if peek () = '[' then begin
      incr pos;
      let g = expr () in
      skip_ws ();
      if peek () <> ']' then fail "']' expected";
      incr pos;
      let d = read_int () in
      let m = marks () in
      if m then fail "transition-based marks are not supported";
      trans := { src = !cur; dst = d; marked = false; cubes = dnf true g } :: !trans
    end
    else fail "unexpected token in the body"
  done;
  let accepting =
    if !all_acc then List.init !nstates (fun i -> i) else List.sort_uniq compare !acc in
  { nstates = !nstates; init = !init; trans = List.rev !trans; accepting; trans_based = false }
