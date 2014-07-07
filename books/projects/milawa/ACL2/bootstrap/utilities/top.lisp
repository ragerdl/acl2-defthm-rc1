; Milawa - A Reflective Theorem Prover
; Copyright (C) 2005-2009 Kookamara LLC
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

(in-package "MILAWA")

(include-book "all-at-leastp")
(include-book "all-equalp")
;(include-book "bitwise-support")          ; shouldn't be necessary
(include-book "clean-update")
(include-book "cons-listp")
(include-book "cons-onto-ranges")
(include-book "defaggregate")
(include-book "deflist")
(include-book "defmap")
(include-book "extended-subsets")
(include-book "fast-remove-supersets")
(include-book "intersect")
(include-book "list-list-fix")
(include-book "listify-each")
(include-book "map-listp")
(include-book "mergesort")
(include-book "mergesort-map")
(include-book "multicons")
(include-book "mutually-disjoint")
(include-book "nat-listp")
(include-book "ordered-subsetp")
(include-book "primitives")
(include-book "remove-duplicates-list")
(include-book "remove-all-from-ranges")
(include-book "simple-flatten")
(include-book "strip-firsts")
(include-book "strip-lens")
(include-book "strip-seconds")
(include-book "strip-thirds")
(include-book "sort-symbols")
(include-book "symbol-listp")
(include-book "total-order")
(include-book "tuple-listp")
(include-book "utilities")


(%create-theory type-set-like-rules)
(%enable type-set-like-rules
         equal-of-non-cons-and-cons-cheap
         equal-of-symbol-and-non-symbol-cheap
         equal-of-non-symbol-and-symbol-cheap
         equal-of-cons-and-non-cons-cheap
         equal-of-nat-and-non-nat-cheap
         equal-of-non-nat-and-nat-cheap
         consp-when-natp-cheap
         consp-when-nothing-else-cheap
         symbolp-when-booleanp-cheap
         symbolp-when-consp-cheap
         symbolp-when-natp-cheap
         car-when-symbolp-cheap
         booleanp-when-natp-cheap
         booleanp-when-consp-cheap)

(%create-theory expensive-arithmetic-rules)
(%enable expensive-arithmetic-rules
         not-equal-when-less
         not-equal-when-less-two
         trichotomy-of-<
         antisymmetry-of-<)

(%create-theory expensive-arithmetic-rules-two)
(%enable expensive-arithmetic-rules-two
         |a <= b, c != 0 --> a < c+b|
         |a <= b, c != 0 --> a < b+c|
         |b <= c, a <= b --> a < 1+c|
         transitivity-of-<
         transitivity-of-<-two
         transitivity-of-<-three
         transitivity-of-<-four
         squeeze-law-two
         one-plus-trick
         less-when-zp-left-cheap
         less-when-zp-right-cheap
         plus-when-zp-right-cheap
         natp-when-zp-cheap
         natp-when-not-zp-cheap
         nfix-when-zp-cheap
         nfix-when-not-natp-cheap
         zp-when-not-natp-cheap
         zp-when-natp-cheap)

(%create-theory expensive-subsetp-rules)
(%enable expensive-subsetp-rules
         subsetp-when-prefixp-cheap
         subsetp-when-ordered-subsetp
         memberp-when-not-subset-of-somep-cheap
         memberp-when-not-superset-of-somep-cheap)

(%create-theory unusual-memberp-rules)
(%enable unusual-memberp-rules
         memberp-when-not-superset-of-somep-cheap
         memberp-when-not-subset-of-somep-cheap
         memberp-when-memberp-of-member-of-nonep-alt)

(%create-theory unusual-subsetp-rules)
(%enable unusual-subsetp-rules
         subsetp-when-prefixp-cheap
         subsetp-when-ordered-subsetp)

(%create-theory unusual-consp-rules)
(%enable unusual-consp-rules
         consp-when-memberp-of-cons-listp-alt
         consp-when-memberp-of-none-consp-alt
         consp-of-cdr-when-tuplep-2-cheap
         consp-of-cdr-when-tuplep-3-cheap
         consp-of-cdr-of-cdr-when-tuplep-3-cheap
         consp-of-car-when-none-consp
         consp-of-car-when-cons-listp
         consp-of-cdr-when-len-two-cheap
         consp-of-cdr-when-memberp-not-car-cheap)

(%create-theory usual-consp-rules)
(%enable usual-consp-rules
         car-when-not-consp
         cdr-when-not-consp
         consp-when-true-listp-cheap
         consp-when-consp-of-cdr-cheap
         cdr-of-cdr-with-len-free-past-the-end
         cdr-when-true-listp-with-len-free-past-the-end
         cdr-of-cdr-when-true-listp-with-len-free-past-the-end
         consp-of-cdr-with-len-free
         consp-of-cdr-of-cdr-with-len-free
         cdr-under-iff-when-true-listp-with-len-free
         cdr-of-cdr-under-iff-when-true-listp-with-len-free)

(%finish "utilities")
(%save-events "utilities.events")

;; Clear out the thmfiles table since we'll use the saved image from now on.
(ACL2::table tactic-harness 'thmfiles nil)
