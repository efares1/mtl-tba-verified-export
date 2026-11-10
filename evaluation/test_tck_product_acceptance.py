#!/usr/bin/env python3
"""Regression test for the acceptance convention of unmarked CASAAL automata
in tck_product.py (the X74 case).

A CASAAL .gv without an Acc[...] mark is read as follows: if some state label
still contains an unbounded eventuality (F or U without an upper bound), the
states without one are accepting, and the language is empty when there is no
such state; otherwise every run is accepting.

Run:  python3 test_tck_product_acceptance.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tck_product as tp  # noqa: E402

EVENTS = ['p', 'q', 'r']


def load(path):
    return tp.from_gv('B', os.path.join(HERE, path), EVENTS)


def main():
    # X74 negation: F(q & r) is never discharged under mutual exclusion, so
    # the automaton accepts nothing: its label sits on an unreachable location.
    a = load('casaal_out_rand/X74_neg.gv')
    assert a.acc_labels == ['accB_weak'], a.acc_labels
    assert 'unreach' in a.locs and a.locs['unreach'][0] == ['accB_weak']
    assert all(v[0] == [] for k, v in a.locs.items() if k != 'unreach')

    # An automaton whose eventuality is discharged by leaving the state keeps
    # an accepting sink: only the states without a pending obligation carry
    # the label.
    a = load('casaal_out_rand/X24.gv')
    assert a.acc_labels == ['accB_weak']
    assert 'unreach' not in a.locs
    labelled = {k for k, v in a.locs.items() if v[0]}
    assert labelled and labelled != set(a.locs), labelled

    # Bounded operators carry their obligation in a clock guard: no label is
    # added, and the automaton still accepts every run (previous behaviour).
    a = load('casaal_out_x/F1.gv')
    assert a.acc_labels == [], a.acc_labels

    print('ok')


if __name__ == '__main__':
    main()
