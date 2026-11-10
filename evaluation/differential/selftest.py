"""Hand-checked sanity tests of the judge (run: python3 selftest.py)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dlib import *
def W(letters, s, delays, t0=2):   # half-units
    return Word(letters, s, delays, t0)
def J(f, w): return judge(parse_mtl(f), w)
ok = True
def check(name, got, exp):
    global ok
    print(('ok   ' if got == exp else 'FAIL ') + name, got, exp)
    ok &= (got == exp)
# p at 0, q at 2 time units later (delay 4 half-units), then 'other' forever (loop)
w = W(['p', 'q', 'other'], 2, [4, 2, 2])           # times (half-units): 2, 6, 8 ...
check('p -> <>[<=2] q holds at 0 (dt = 2)', J('p -> <>[<=2] q', w), True)
check('p -> <>[<2] q fails (dt = 2 not < 2)', J('p -> <>[<2] q', w), False)
check('<>[>=2] q at 0', J('<>[>=2] q', w), True)
check('<>[>2] q at 0 (dt=2 not > 2)', J('<>[>2] q', w), False)
check('[](p -> <>[<=2] q)', J('[](p -> <>[<=2] q)', w), True)
check('[]<> q false (q only once)', J('[]<> q', w), False)
check('<>[] !q true', J('<>[] !q', w), True)
check('p U q', J('p U q', w), True)
check('p U[<=1] q false (dt = 2)', J('p U[<=1] q', w), False)
check('p U[<=2] q true', J('p U[<=2] q', w), True)
check('X q', J('X q', w), True)
check('^<>[<=2] q at 0 (strict future): true', J('^<>[<=2] q', w), True)
check('q ^U other (q at 1, other at 2): true', J('q ^U other', w), True)
# loop alternates a, b every 1 unit
w2 = W(['a', 'b'], 0, [2, 2], 2)
check('[]<> a', J('[]<> a', w2), True)
check('[]<>[<=1] a (a every 2 units: from b next a at +1)', J('[](b -> <>[<=1] a)', w2), True)
check('[](a -> [][<=1] !a) false: [] includes the current position', J('[](a -> [][<=1] !a)', w2), False)
check('[](a -> ^[][<=1] !a) true (hatted: strictly future)', J('[](a -> ^[][<=1] !a)', w2), True)
check('[](a -> [][<=2] !a) false (a recurs at +2)', J('[](a -> [][<=2] !a)', w2), False)
check('[](a -> ^[][<2] !a) true', J('[](a -> ^[][<2] !a)', w2), True)
check('[](a -> ^[][<=2] !a) false', J('[](a -> ^[][<=2] !a)', w2), False)
check('a R b? (b must hold until a)', J('a R b', w2), False)
check('false R b  ==  [] b', J('false R b', w2), False)
check('[]( a | b )', J('[](a|b)', w2), True)
check('<>[>=1] b at 0 with time dt 1', J('<>[>=1] b', w2), True)
check('[>=3] b: first b at +1, then +3', J('<>[>=3] b', w2), True)
# hat: ^<> excludes current position
check('^<>[<=0] a not at 0 (strictly future): [<=0] none', J('^<>[<=0] a', w2), False)
print('ALL OK' if ok else 'SOME FAILED')
