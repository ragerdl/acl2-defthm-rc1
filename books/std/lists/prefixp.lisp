; Prefixp function and lemmas
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
; prefixp.lisp
; This file was originally part of the Unicode library.

(in-package "ACL2")
(include-book "equiv")
(local (include-book "take"))

(local (defthm commutativity-2-of-+
         (equal (+ x (+ y z))
                (+ y (+ x z)))))

(local (defthm fold-consts-in-+
         (implies (and (syntaxp (quotep x))
                       (syntaxp (quotep y)))
                  (equal (+ x (+ y z)) (+ (+ x y) z)))))

(defsection prefixp
  :parents (std/lists)
  :short "@(call prefixp) determines if the list @('x') occurs at the front of
the list @('y')."

  (defund prefixp (x y)
    (declare (xargs :guard t))
    (if (consp x)
        (and (consp y)
             (equal (car x) (car y))
             (prefixp (cdr x) (cdr y)))
      t))

  (defthm prefixp-when-not-consp-left
    (implies (not (consp x))
             (prefixp x y))
    :hints(("Goal" :in-theory (enable prefixp))))

  (defthm prefixp-of-cons-left
    (equal (prefixp (cons a x) y)
           (and (consp y)
                (equal a (car y))
                (prefixp x (cdr y))))
    :hints(("Goal" :in-theory (enable prefixp))))

  (defthm prefixp-when-not-consp-right
    (implies (not (consp y))
             (equal (prefixp x y)
                    (not (consp x))))
    :hints(("Goal" :induct (len x))))

  (defthm prefixp-of-cons-right
    (equal (prefixp x (cons a y))
           (if (consp x)
               (and (equal (car x) a)
                    (prefixp (cdr x) y))
             t)))

  (defthm prefixp-of-list-fix-left
    (equal (prefixp (list-fix x) y)
           (prefixp x y))
    :hints(("Goal" :in-theory (enable prefixp))))

  (defthm prefixp-of-list-fix-right
    (equal (prefixp x (list-fix y))
           (prefixp x y))
    :hints(("Goal" :in-theory (enable prefixp))))

  (defcong list-equiv equal (prefixp x y) 1
    :hints(("Goal"
            :in-theory (disable prefixp-of-list-fix-left)
            :use ((:instance prefixp-of-list-fix-left)
                  (:instance prefixp-of-list-fix-left (x x-equiv))))))

  (defcong list-equiv equal (prefixp x y) 2
    :hints(("Goal"
            :in-theory (disable prefixp-of-list-fix-right)
            :use ((:instance prefixp-of-list-fix-right)
                  (:instance prefixp-of-list-fix-right (y y-equiv))))))

  (defthm len-when-prefixp
    (implies (prefixp x y)
             (equal (< (len y) (len x))
                    nil))
    :rule-classes ((:rewrite)
                   (:linear :corollary (implies (prefixp x y)
                                                (<= (len x) (len y)))))
    :hints(("Goal" :in-theory (enable (:induction prefixp)))))

  (defthm take-when-prefixp
    (implies (prefixp x y)
             (equal (take (len x) y)
                    (list-fix x)))
    :hints(("Goal" :in-theory (enable (:induction prefixp)))))

  (defthm prefixp-of-take
    (equal (prefixp (take n x) x)
           (<= (nfix n) (len x)))
    :hints(("Goal" :in-theory (enable acl2::take-redefinition))))

  (defthm prefixp-reflexive
    (prefixp x x)
    :hints(("Goal" :induct (len x))))

  (defthm prefixp-of-append
    (prefixp x (append x y)))

  (local (defthm equal-len-0
           (equal (equal (len x) 0)
                  (atom x))))

  (defthm prefixp-of-append-when-same-length
    (implies (equal (len x) (len y))
             (equal (prefixp x (append y z))
                    (prefixp x y)))
    :hints(("Goal"
            :induct (prefixp x y)
            :in-theory (enable prefixp
                               list-equiv))))

  (defthm prefixp-when-equal-lengths
    (implies (equal (len x) (len y))
             (equal (prefixp x y)
                    (list-equiv x y)))
    :hints(("Goal" :in-theory (enable prefixp list-equiv)))))
