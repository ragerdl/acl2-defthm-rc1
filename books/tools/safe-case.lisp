; Safe-Case Macro
; Copyright (C) 2008-2010 Centaur Technology
;
; Contact:
;   Centaur Technology Formal Verification Group
;   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
;   http://www.centtech.com/
;
; License: (An MIT/X11-style license)
;
;   Permission is hereby granted, free of charge, to any person obtaining a
;   copy of this software and associated documentation files (the "Software"),
;   to deal in the Software without restriction, including without limitation
;   the rights to use, copy, modify, merge, publish, distribute, sublicense,
;   and/or sell copies of the Software, and to permit persons to whom the
;   Software is furnished to do so, subject to the following conditions:
;
;   The above copyright notice and this permission notice shall be included in
;   all copies or substantial portions of the Software.
;
;   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;   DEALINGS IN THE SOFTWARE.
;
; Original author: Jared Davis <jared@centtech.com>

(in-package "ACL2")
(include-book "xdoc/top" :dir :system)

(defsection safe-case
  :parents (case)
  :short "Error-checking alternative to @(see case)."

  :long "<p>@('Safe-case') is a drop-in replacement for @(see case) and is
logically identical to @('case').  The only difference is that @('safe-case')
adds some extra error-checking during execution.</p>

<p>In particular, when @('case') is used and none of the cases match, the
answer is @('nil'):</p>

@({
    ACL2 !> (case 3
              (1 'one)
              (2 'two))
    NIL
})

<p>But when @('safe-case') is used and none of the cases match, the result is
an error:</p>

@({
    ACL2 !> (safe-case (+ 0 3)
              (1 'one)
              (2 'two))

    HARD ACL2 ERROR in SAFE-CASE:  No case matched:
    (SAFE-CASE (+ 0 3) (1 'ONE) (2 'TWO)).  Test was 3.
})

<p>To use @('safe-case') you need to include it, e.g.,:</p>

@({
    (include-book \"tools/safe-case\" :dir :system)
})"

  (defmacro safe-case (&rest l)
    (declare (xargs :guard (and (consp l)
                                (legal-case-clausesp (cdr l)))))
    (let* ((clauses (cdr l))
           (tests   (strip-cars clauses)))
      (if (or (member t tests)
              (member 'otherwise tests))
          `(case ,@l)
        `(case ,@l
           (otherwise
            (er hard? 'safe-case "No case matched: ~x0.  Test was ~x1.~%"
                '(safe-case ,@l) ,(car l))))))))
