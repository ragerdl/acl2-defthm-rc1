; Defsort - Defines a stable sort when given a comparison function
; Copyright (C) 2008 Centaur Technology
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
(include-book "defsort")
(include-book "misc/total-order" :dir :system)
(include-book "std/util/define" :dir :system)

(defsort :compare< <<
         :prefix <<)

(define no-adjacent-duplicates-p (x)
  :parents (uniquep)
  (cond ((atom x)
         t)
        ((atom (cdr x))
         t)
        (t
         (and (not (equal (car x) (cadr x)))
              (no-adjacent-duplicates-p (cdr x))))))

(define uniquep (x)
  :parents (no-duplicatesp)
  :short "Sometimes better than @(see no-duplicatesp): first sorts the list and
then looks for adjacent duplicates."

  :long "<p>@(call uniquep) is provably equal to @('(no-duplicatesp x)'), but
has different performance characteristics.  It operates by sorting its argument
and then scanning for adjacent duplicates.</p>

<p>Note: we leave this function enabled.  You should never write a theorem
about @('uniquep').  Reason about @(see no-duplicatesp) instead.</p>

<p>Since we use a mergesort, the complexity of @('uniquep') is @('O(n log n)').
By comparison, @('no-duplicatesp') is @('O(n^2)').</p>

<p>It is not always better to use @('uniquep') than @('no-duplicatesp'):</p>

<ul>

<li>It uses far more memory than @('no-duplicatesp') because it sorts the
list.</li>

<li>On a list with lots of duplicates, @('no-duplicatesp') may find a duplicate
very quickly and stop early, but @('uniquep') has to sort the whole list before
it looks for any duplicates.</li>

</ul>

<p>However, if your lists are sometimes long with few duplicates, @('uniquep')
is probably a much better function to use.</p>"

  :inline t
  :enabled t

  (mbe :logic (no-duplicatesp x)
       :exec (no-adjacent-duplicates-p (<<-sort x)))

  :prepwork
  ((local (defthm lemma
            (implies (<<-ordered-p x)
                     (equal (no-adjacent-duplicates-p x)
                            (no-duplicatesp x)))
            :hints(("Goal" :in-theory (enable no-duplicatesp
                                              no-adjacent-duplicates-p
                                              <<-ordered-p)))))))


#||

Below is only performance-test stuff.  Tested on CCL on Lisp2.

:q

(ccl::set-lisp-heap-gc-threshold (expt 2 30))

(defparameter *integers1*
  ;; A test vector of 10,000 integers with many duplicates
  (loop for j from 1 to 10
        nconc
        (loop for i from 1 to 1000 collect i)))

(defparameter *integers2*
  ;; A test vector of 10,000 integers with no duplicates
  (loop for i from 1 to 10000 collect i)))


;; In certain cases, no-duplicatesp-equal is much faster because a duplicate is
;; found right away.  For instance, on *integers1*, which contains lots of
;; duplicates, we only have to scan a little to find a match.

;; 0.0 seconds, no allocation
(prog2$ (ccl::gc)
        (time (loop for i fixnum from 1 to 1000
                   do
                   (let ((result (no-duplicatesp-equal *integers1*)))
                     (declare (ignore result))
                     nil))))

;; 4.2 seconds, 1.5 GB allocated
(prog2$ (ccl::gc)
        (time (loop for i fixnum from 1 to 1000
                   do
                   (let ((result (uniquep *integers1*)))
                     (declare (ignore result))
                     nil))))



;; In other cases, uniquep is much faster because it is O(n log n) instead of
;; O(n^2).

;; 27.4 seconds, no allocation.
(prog2$ (ccl::gc)
        (time (loop for i fixnum from 1 to 100
                   do
                   (let ((result (no-duplicatesp-equal *integers2*)))
                     (declare (ignore result))
                     nil))))


;; 0.2 seconds, 120 MB allocated
(prog2$ (ccl::gc)
        (time (loop for i fixnum from 1 to 100
                   do
                   (let ((result (uniquep *integers2*)))
                     (declare (ignore result))
                     nil))))


||#