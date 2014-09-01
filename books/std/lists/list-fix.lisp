; List-fix function and lemmas
; Copyright (C) 2005-2013 Kookamara LLC
;
; Contact:
;
;   Kookamara LLC
;   11410 Windermere Meadows
;   Austin, TX 78759, USA
;   http://www.kookamara.com/
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
; Original author: Jared Davis <jared@kookamara.com>
;
; list-fix.lisp
; This file was originally part of the Unicode library.

(in-package "ACL2")
(include-book "abstract")

(defsection list-fix
  :parents (std/lists)
  :short "@(call list-fix) converts @('x') into a @(see true-listp) by, if
necessary, changing its @(see final-cdr) to @('nil')."

  :long "<p>Many functions that processes lists follows the <b>list-fix
convention</b>: whenever @('f') is given a some non-@('true-listp') @('a')
where it expected a list, it will act as though it had been given @('(list-fix
a)') instead.  As a few examples, logically,</p>

<ul>
<li>@('(endp x)') ignores the final @('cdr') of @('x'),</li>
<li>@('(len x)') ignores the final @('cdr') of @('x'),</li>
<li>@('(append x y)') ignores the final @('cdr') of @('x') (but not @('y'))</li>
<li>@('(member a x)') ignores the final @('cdr') of @('x'), etc.</li>
</ul>

<p>Having a @('list-fix') function is often useful when writing theorems about
how list-processing functions behave.  For example, it allows us to write
strong, hypothesis-free theorems such as:</p>

@({
    (equal (character-listp (append x y))
           (and (character-listp (list-fix x))
                (character-listp y)))
})

<p>Indeed, @('list-fix') is the basis for @(see list-equiv), an extremely
common @(see equivalence) relation.</p>"

  (defund list-fix (x)
    (declare (xargs :guard t))
    (if (consp x)
        (cons (car x)
              (list-fix (cdr x)))
      nil))

  (defthm list-fix-when-not-consp
    (implies (not (consp x))
             (equal (list-fix x)
                    nil))
    :hints(("Goal" :in-theory (enable list-fix))))

  (defthm list-fix-of-cons
    (equal (list-fix (cons a x))
           (cons a (list-fix x)))
    :hints(("Goal" :in-theory (enable list-fix))))

  (defthm car-of-list-fix
    (equal (car (list-fix x))
           (car x)))

  (defthm cdr-of-list-fix
    (equal (cdr (list-fix x))
           (list-fix (cdr x))))

  (defthm list-fix-when-len-zero
    (implies (equal (len x) 0)
             (equal (list-fix x)
                    nil)))

  (defthm true-listp-of-list-fix
    (true-listp (list-fix x)))

  (defthm len-of-list-fix
    (equal (len (list-fix x))
           (len x)))

  (defthm list-fix-when-true-listp
    (implies (true-listp x)
             (equal (list-fix x) x)))

  (defthm list-fix-under-iff
    (iff (list-fix x)
         (consp x))
    :hints(("Goal" :induct (len x))))

  (defthm consp-of-list-fix
    (equal (consp (list-fix x))
           (consp x))
    :hints(("Goal" :induct (len x))))

  (defthm last-of-list-fix
    (equal (last (list-fix x))
           (list-fix (last x))))

  (defthm equal-of-list-fix-and-self
    (equal (equal x (list-fix x))
           (true-listp x)))

  (def-listp-rule element-list-p-of-list-fix-non-true-listp
    (implies (element-list-final-cdr-p t)
             (equal (element-list-p (list-fix x))
                    (element-list-p x)))
    :hints(("Goal" :in-theory (enable list-fix)))
    :requirement (not true-listp)
    :name element-list-p-of-list-fix
    :body (equal (element-list-p (list-fix x))
                    (element-list-p x)))

  (def-listp-rule element-list-p-of-list-fix-true-listp
    (implies (element-list-p x)
             (element-list-p (list-fix x)))
    :hints(("Goal" :in-theory (enable list-fix)))
    :requirement true-listp
    :name element-list-p-of-list-fix)


  (def-listfix-rule element-list-fix-of-list-fix-true-list
    (implies (not (element-list-final-cdr-p t))
             (equal (element-list-fix (list-fix x))
                    (element-list-fix x)))
    :hints(("Goal" :in-theory (enable list-fix)))
    :requirement true-listp
    :name element-list-fix-of-list-fix
    :body (equal (element-list-fix (list-fix x))
                    (element-list-fix x)))

  (def-listfix-rule element-list-fix-of-list-fix-non-true-list
    (implies (element-list-final-cdr-p t)
             (equal (element-list-fix (list-fix x))
                    (list-fix (element-list-fix x))))
    :hints(("Goal" :in-theory (enable list-fix)))
    :requirement (not true-listp)
    :name element-list-fix-of-list-fix
    :body (equal (element-list-fix (list-fix x))
                 (list-fix (element-list-fix x))))

  (def-projection-rule elementlist-projection-of-list-fix
    (equal (elementlist-projection (list-fix x))
           (elementlist-projection x)))

  (def-mapappend-rule elementlist-mapappend-of-list-fix
    (equal (elementlist-mapappend (list-fix x))
           (elementlist-mapappend x))))
