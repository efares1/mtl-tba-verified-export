// lang_cmp: bounded differential test of two timed Buchi automata (testing oracle).
//
// Both automata are read in a small canonical text format (see to_canon.py):
//   E <n>                 number of event ids; the last id (n-1) is the event "other"
//   C <n>                 number of clocks
//   L <n>                 number of locations
//   I <loc>               initial location
//   A <k> <loc>*k         accepting locations
//   V <loc> <k> (<clock> <bound2>)*k      upper-bound invariant (bound in half-time-units)
//   T <src> <dst> <evmask> <ng> (<kind> <c1> <c2> <b2>)*ng <nr> <clock>*nr
//        kind 0..4: clock c1 (<=,<,>=,>,==) b2 ; kind 5: c1 - c2 <= b2
// Time is counted in half units; all bounds are multiples of 1/2.
//
// A test word is ultimately periodic: a prefix of length P (0..3) and a loop of length
// Lp (1..3) repeated forever, with a delay (in half units) after every event, the loop
// having a positive total delay (time diverges).  The run starts in the initial
// location with a given initial clock valuation v0 (the first valuation is all zeros,
// the others random).  Acceptance of a word (for a fixed v0) is approximated on the
// unrolled word: there is a run through R loop iterations such that the accepting set
// is visited in every iteration after the first R0, where R0 is large enough for every
// clock that is not reset in the loop to exceed all constants (R0 = (maxconst+4)/loopdelay+2)
// and R = R0 + 12.  The same words and the same
// valuations are used for both automata; a "mismatch" is a (word, v0) pair on which
// exactly one of them accepts.  Location invariants are checked at the end of the stay
// in the target location (upper bounds, so this is the strongest point).
//
// usage: lang_cmp A.can B.can nwords seed [first_word_index]
// output: one line "words=.. pairs=.. mismatch=.. first=<index or -1> accA=.. accB=.."
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <vector>
#include <array>
#include <algorithm>
#include <string>
#include <fstream>
#include <sstream>
using namespace std;
const int MAXC = 8;
// number of loop iterations checked after the R0 warm-up iterations (default 12; LANGCMP_EXTRA overrides it).  A finite horizon can
// make two automata differ at its end when a run survives it only by a bounded stay; a larger value removes such artifacts.
static const int EXTRA = getenv("LANGCMP_EXTRA") ? atoi(getenv("LANGCMP_EXTRA")) : 12;
typedef array<int, MAXC> Val;
struct Atom { int kind, c1, c2, b; };
struct Tr { int src, dst; unsigned mask; vector<Atom> g; vector<int> rs; };
struct Aut {
  int E = 0, nc = 0, nl = 0, init = 0;
  vector<char> acc;
  vector<vector<pair<int,int>>> inv;
  vector<Tr> tr;
  vector<vector<int>> out;
  int maxconst = 0; // in half units
};
static bool read_aut(const char* fn, Aut& a) {
  ifstream f(fn);
  if (!f) { fprintf(stderr, "cannot open %s\n", fn); return false; }
  string line;
  while (getline(f, line)) {
    istringstream is(line); string k; is >> k;
    if (k == "E") is >> a.E;
    else if (k == "C") { is >> a.nc; }
    else if (k == "L") { is >> a.nl; a.acc.assign(a.nl, 0); a.inv.assign(a.nl, {}); a.out.assign(a.nl, {}); }
    else if (k == "I") is >> a.init;
    else if (k == "A") { int n; is >> n; while (n--) { int l; is >> l; a.acc[l] = 1; } }
    else if (k == "V") { int l, n; is >> l >> n; while (n--) { int c, b; is >> c >> b; a.inv[l].push_back({c, b}); a.maxconst = max(a.maxconst, abs(b)); } }
    else if (k == "T") {
      Tr t; int ng, nr; is >> t.src >> t.dst >> t.mask >> ng;
      for (int i = 0; i < ng; i++) { Atom x; is >> x.kind >> x.c1 >> x.c2 >> x.b; t.g.push_back(x); a.maxconst = max(a.maxconst, abs(x.b)); }
      is >> nr; for (int i = 0; i < nr; i++) { int c; is >> c; t.rs.push_back(c); }
      a.out[t.src].push_back((int)a.tr.size()); a.tr.push_back(t);
    }
  }
  return true;
}
static inline bool holds(const Atom& x, const Val& v) {
  switch (x.kind) {
    case 0: return v[x.c1] <= x.b;
    case 1: return v[x.c1] < x.b;
    case 2: return v[x.c1] >= x.b;
    case 3: return v[x.c1] > x.b;
    case 4: return v[x.c1] == x.b;
    default: return v[x.c1] - v[x.c2] <= x.b;
  }
}
struct St { int loc; int flag; Val v; };
static bool operator<(const St& a, const St& b) {
  if (a.loc != b.loc) return a.loc < b.loc;
  if (a.flag != b.flag) return a.flag < b.flag;
  return a.v < b.v;
}
static bool operator==(const St& a, const St& b) { return a.loc == b.loc && a.flag == b.flag && a.v == b.v; }

struct Word { int P, Lp; int ev[8]; int dl[8]; int R, R0; };

static bool accepts(const Aut& a, const Word& w, const Val& v0) {
  vector<St> cur, nxt;
  St s0; s0.loc = a.init; s0.flag = 0; s0.v = v0; cur.push_back(s0);
  int N = w.P + w.R * w.Lp; int R0 = w.R0;
  for (int n = 0; n < N; n++) {
    int idx = n < w.P ? n : w.P + (n - w.P) % w.Lp;
    int e = w.ev[idx], d = w.dl[idx];
    nxt.clear();
    for (const St& s : cur) {
      for (int ti : a.out[s.loc]) {
        const Tr& t = a.tr[ti];
        if (!((t.mask >> e) & 1u)) continue;
        bool ok = true;
        for (const Atom& x : t.g) if (!holds(x, s.v)) { ok = false; break; }
        if (!ok) continue;
        St r; r.loc = t.dst; r.v = s.v;
        for (int c : t.rs) r.v[c] = 0;
        for (int c = 0; c < a.nc; c++) r.v[c] += d;
        bool iv = true;
        for (auto& p : a.inv[t.dst]) if (r.v[p.first] > p.second) { iv = false; break; }
        if (!iv) continue;
        r.flag = s.flag || a.acc[t.dst];
        nxt.push_back(r);
      }
    }
    if (n + 1 >= w.P && (n + 1 - w.P) % w.Lp == 0) {
      int it = (n + 1 - w.P) / w.Lp;
      if (it > R0) { size_t k = 0; for (auto& s : nxt) if (s.flag) nxt[k++] = s; nxt.resize(k); }
      for (auto& s : nxt) s.flag = 0;
    }
    sort(nxt.begin(), nxt.end());
    nxt.erase(unique(nxt.begin(), nxt.end()), nxt.end());
    cur.swap(nxt);
    if (cur.empty()) return false;
  }
  return !cur.empty();
}
static uint64_t rs;
static uint64_t rnd() { rs ^= rs << 13; rs ^= rs >> 7; rs ^= rs << 17; return rs; }
static int rint(int n) { return (int)(rnd() % (uint64_t)n); }

// Exhaustive mode: lang_cmp A B exh d1,d2,.. [v1,v2,..] [maxpos]  enumerates EVERY lasso word (prefix 0..3 and loop 1..3, with
// prefix+loop <= 4 positions) over all events and the given delay values (half units), starting from EVERY initial valuation in the grid v1,v2,.. (default 0) for each clock, and counts the words on which exactly one automaton accepts.  Exact on this finite word set only.
static vector<int> parse_list(const char* dl) { vector<int> D; string s(dl); stringstream ss(s); string tok; while (getline(ss, tok, ',')) D.push_back(atoi(tok.c_str())); return D; }
static int exhaustive(const Aut& A, const Aut& B, const char* dl, const char* vl, int maxpos) {
  vector<int> D = parse_list(dl); vector<int> VL = parse_list(vl);
  int E = max(A.E, B.E); int nc = max(A.nc, B.nc);
  if (nc > MAXC) { fprintf(stderr, "too many clocks\n"); return 2; }
  int M = max(A.maxconst, B.maxconst);
  int nopt = E * (int)D.size();
  long words = 0, mism = 0, accA = 0, accB = 0; long firstm = -1;
  static const int cfg[][2] = {{0,1},{0,2},{0,3},{1,1},{1,2},{1,3},{2,1},{2,2},{3,1}};
  for (auto& c : cfg) {
    int P = c[0], Lp = c[1], n = P + Lp;
    if (n > maxpos) continue;
    long total = 1; for (int i = 0; i < n; i++) total *= nopt;
    for (long code = 0; code < total; code++) {
      Word w; w.P = P; w.Lp = Lp; long x = code; int tot = 0;
      for (int i = 0; i < n; i++) { int o = (int)(x % nopt); x /= nopt; w.ev[i] = o / (int)D.size(); w.dl[i] = D[o % (int)D.size()]; if (i >= P) tot += w.dl[i]; }
      if (tot == 0) continue;
      w.R0 = (M + 4) / tot + 2; w.R = w.R0 + EXTRA;
      long nv = 1; for (int k = 0; k < nc; k++) nv *= (long)VL.size();
      for (long vc = 0; vc < nv; vc++) {
        Val v0; v0.fill(0); long y = vc;
        for (int k = 0; k < nc; k++) { v0[k] = VL[y % (long)VL.size()]; y /= (long)VL.size(); }
        bool a = accepts(A, w, v0), b = accepts(B, w, v0);
        words++; accA += a; accB += b;
        if (a != b) { mism++; if (firstm < 0) firstm = words; }
      }
    }
  }
  printf("words=%ld pairs=%ld mismatch=%ld first=%ld accA=%ld accB=%ld\n", words, words, mism, firstm, accA, accB);
  return 0;
}

int main(int argc, char** argv) {
  if (argc < 4) { fprintf(stderr, "usage: lang_cmp A B nwords seed [first] | lang_cmp A B exh d1,d2,..\n"); return 2; }
  Aut A, B;
  if (!read_aut(argv[1], A) || !read_aut(argv[2], B)) return 2;
  if (string(argv[3]) == "exh") return exhaustive(A, B, argc > 4 ? argv[4] : "0,1,2,3,5,10", argc > 5 ? argv[5] : "0", argc > 6 ? atoi(argv[6]) : 4);
  if (argc < 5) { fprintf(stderr, "usage: lang_cmp A B nwords seed [first]\n"); return 2; }
  long nwords = atol(argv[3]); uint64_t seed = strtoull(argv[4], 0, 10);
  long first = argc > 5 ? atol(argv[5]) : 0;
  int E = max(A.E, B.E); int nc = max(A.nc, B.nc);
  if (nc > MAXC) { fprintf(stderr, "too many clocks\n"); return 2; }
  int M = max(A.maxconst, B.maxconst);
  static const int delays[] = {0, 0, 1, 1, 2, 2, 3, 4, 5, 6, 8};
  const int ND = sizeof(delays) / sizeof(int);
  long pairs = 0, mism = 0, firstm = -1, accA = 0, accB = 0;
  const int NV = 6;
  for (long wi = first; wi < first + nwords; wi++) {
    rs = seed * 1000003ULL + (uint64_t)wi * 7919ULL + 88172645463325252ULL; for (int i = 0; i < 5; i++) rnd();
    Word w; w.P = rint(4); w.Lp = 1 + rint(3);
    int tot = 0;
    for (int i = 0; i < w.P + w.Lp; i++) {
      w.ev[i] = rint(E);
      w.dl[i] = delays[rint(ND)];
      if (i >= w.P) tot += w.dl[i];
    }
    if (tot == 0) { int k = w.P + rint(w.Lp); w.dl[k] = 1 + rint(4); tot = w.dl[k]; }
    // enough iterations for every clock that is not reset in the loop to exceed all constants,
    // then 12 more iterations in each of which an accepting location must be visited
    w.R0 = (M + 4) / tot + 2; w.R = w.R0 + EXTRA;
    bool wm = false;
    for (int k = 0; k < NV; k++) {
      Val v0; v0.fill(0);
      if (k > 0) for (int c = 0; c < nc; c++) v0[c] = rint(M + 3);
      bool x = accepts(A, w, v0), y = accepts(B, w, v0);
      pairs++; accA += x; accB += y;
      if (x != y) { mism++; if (!wm) { wm = true; if (firstm < 0) firstm = wi; } }
    }
  }
  printf("words=%ld pairs=%ld mismatch=%ld first=%ld accA=%ld accB=%ld\n", nwords, pairs, mism, firstm, accA, accB);
  return 0;
}
