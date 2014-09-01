; Take lemmas
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
; take.lisp
; This file was originally part of the Unicode library.

(in-package "ACL2")
(include-book "list-fix")
(include-book "equiv")
(local (include-book "std/basic/inductions" :dir :system))

(local (defthm commutativity-2-of-+
         (equal (+ x (+ y z))
                (+ y (+ x z)))))

(local (defthm fold-consts-in-+
         (implies (and (syntaxp (quotep x))
                       (syntaxp (quotep y)))
                  (equal (+ x (+ y z)) (+ (+ x y) z)))))

(local (defthm distributivity-of-minus-over-+
         (equal (- (+ x y)) (+ (- x) (- y)))))

(defun simpler-take-induction (n xs)
  ;; Not generally meant to be used; only meant for take-induction
  ;; and take-redefinition.
  (if (zp n)
      nil
    (cons (car xs)
          (simpler-take-induction (1- n) (cdr xs)))))


(in-theory (disable (:definition take)))

(defsection std/lists/take
  :parents (std/lists take)
  :short "Lemmas about @(see take) available in the @(see std/lists) library."

  :long "<p>ACL2's built-in definition of @('take') is not especially good for
reasoning since it is written in terms of the tail-recursive function
@('first-n-ac').  We provide a much nicer @(see definition) rule:</p>

  @(def take-redefinition)

<p>And we also set up an analogous @(see induction) rule.  We generally
recommend using @('take-redefinition') instead of @('(:definition take)').</p>"

  (encapsulate
    ()
    (local (in-theory (enable take)))

    (local (defthm equivalence-lemma
             (implies (true-listp acc)
                      (equal (first-n-ac n xs acc)
                             (revappend acc (simpler-take-induction n xs))))))

    (defthm take-redefinition
      (equal (take n x)
             (if (zp n)
                 nil
               (cons (car x)
                     (take (1- n) (cdr x)))))
      :rule-classes ((:definition :controller-alist ((TAKE T NIL))))))

  (defthm take-induction t
    :rule-classes ((:induction
                    :pattern (take n x)
                    :scheme (simpler-take-induction n x))))

  ;; The built-in type-prescription for take is awful:
  ;;
  ;; (OR (CONSP (TAKE N L))
  ;;            (EQUAL (TAKE N L) NIL)
  ;;            (STRINGP (TAKE N L)))
  ;;
  ;; So fix it...

  (in-theory (disable (:type-prescription take)))

  (defthm true-listp-of-take
    (true-listp (take n xs))
    :rule-classes :type-prescription)

  (defthm consp-of-take
    (equal (consp (take n xs))
           (not (zp n))))

  (defthm take-under-iff
    (iff (take n xs)
         (not (zp n))))

  (defthm len-of-take
    (equal (len (take n xs))
           (nfix n)))

  (defthm take-of-cons
    (equal (take n (cons a x))
           (if (zp n)
               nil
             (cons a (take (1- n) x)))))

  (defthm take-of-append
    (equal (take n (append x y))
           (if (< (nfix n) (len x))
               (take n x)
             (append x (take (- n (len x)) y))))
    :hints(("Goal" :induct (take n x))))

  (defthm take-of-zero
    (equal (take 0 x)
           nil))

  (defthm take-of-1
    (equal (take 1 x)
           (list (car x))))

  (defthm car-of-take
    (implies (<= 1 (nfix n))
             (equal (car (take n x))
                    (car x))))

  (defthm second-of-take
    (implies (<= 2 (nfix n))
             (equal (second (take n x))
                    (second x))))

  (defthm third-of-take
    (implies (<= 3 (nfix n))
             (equal (third (take n x))
                    (third x))))

  (defthm fourth-of-take
    (implies (<= 4 (nfix n))
             (equal (fourth (take n x))
                    (fourth x))))

  (defthm take-of-len-free
    (implies (equal len (len x))
             (equal (take len x)
                    (list-fix x))))

  (defthm equal-of-take-and-list-fix
    (equal (equal (take n x) (list-fix x))
           (equal (len x) (nfix n))))

  (defthm take-of-len
    (equal (take (len x) x)
           (list-fix x)))

  (defthm subsetp-of-take
    (implies (<= (nfix n) (len x))
             (subsetp (take n x) x)))

  (defthm take-fewer-of-take-more
    ;; Note: see also replicate.lisp for related cases and a stronger rule that
    ;; case-splits.
    (implies (<= (nfix a) (nfix b))
             (equal (take a (take b x))
                    (take a x))))

  (defthm take-of-take-same
    ;; Note: see also replicate.lisp for related cases and a stronger rule that
    ;; case-splits.
    (equal (take a (take a x))
           (take a x)))


  (defcong list-equiv equal (take n x) 2
    :hints(("Goal"
            :induct (and (take n x)
                         (cdr-cdr-induct x x-equiv)))))

  (defcong list-equiv equal (take n x) 2)


  (defcong list-equiv equal (butlast lst n) 1
    :hints(("Goal" :induct (cdr-cdr-induct lst lst-equiv)))))


(defsection first-n
  :parents (std/lists take)
  :short "@(call first-n) is logically identical to @('(take n x)'), but its
guard does not require @('(true-listp x)')."

  :long "<p><b>Reasoning Note.</b> We leave @('first-n') enabled, so it will
just get rewritten into @('take').  You should typically never write a theorem
about @('first-n'): write theorems about @('take') instead.</p>"

  (local (defun replicate (n x)
           (if (zp n)
               nil
             (cons x (replicate (- n 1) x)))))

  (local (defthm l0
           (equal (append (replicate n x) (cons x y))
                  (cons x (append (replicate n x) y)))))

  (local (defthm l1
           (equal (make-list-ac n val acc)
                  (append (replicate n val) acc))
           :hints(("Goal"
                   :induct (make-list-ac n val acc)))))

  (local (defthm l2
           (implies (atom x)
                    (equal (take n x)
                           (make-list n)))))

  (defun first-n (n x)
    (declare (xargs :guard (natp n)))
    (mbe :logic (take n x)
         :exec
         (cond ((zp n)
                nil)
               ((atom x)
                (make-list n))
               (t
                (cons (car x)
                      (first-n (- n 1) (cdr x))))))))
