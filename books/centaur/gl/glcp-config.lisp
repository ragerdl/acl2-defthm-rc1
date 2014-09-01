; GL - A Symbolic Simulation Framework for ACL2
; Copyright (C) 2008-2013 Centaur Technology
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
; Original author: Sol Swords <sswords@centtech.com>

(in-package "GL")
(include-book "shape-spec-defs")

(std::defaggregate glcp-config
  ((abort-unknown booleanp :default t)
   (abort-ctrex booleanp :default t)
   (exec-ctrex booleanp :default t)
   (abort-vacuous booleanp :default t)
   (check-vacuous booleanp :default t)
   (nexamples natp :rule-classes :type-prescription :default 3)
   (hyp-clk natp :rule-classes :type-prescription :default 1000000)
   (concl-clk natp :rule-classes :type-prescription :default 1000000)
   (clause-proc-name symbolp :rule-classes :type-prescription)
   (overrides) ;;  acl2::interp-defs-alistp but might be too expensive to check
     ;;  the guards in clause processors
   (param-bfr :default t)
   top-level-term
   (shape-spec-alist shape-spec-bindingsp)
   run-before
   run-after
   case-split-override
   (split-conses booleanp :default nil)
   (split-fncalls booleanp :default nil)
   (lift-ifsp booleanp :default nil)
   )
  :tag :glcp-config)


(defund-inline glcp-config-update-param (p config)
  (declare (xargs :guard (glcp-config-p config)))
  (change-glcp-config config :param-bfr p))

(defthm param-bfr-of-glcp-config-update-param
  (equal (glcp-config->param-bfr (glcp-config-update-param p config))
         p)
  :hints(("Goal" :in-theory (enable glcp-config-update-param))))

(defthm glcp-config->overrides-of-glcp-config-update-param
  (equal (glcp-config->overrides (glcp-config-update-param p config))
         (glcp-config->overrides config))
  :hints(("Goal" :in-theory (enable glcp-config-update-param))))

(defthm glcp-config->top-level-term-of-glcp-config-update-param
  (equal (glcp-config->top-level-term (glcp-config-update-param p config))
         (glcp-config->top-level-term config))
  :hints(("Goal" :in-theory (enable glcp-config-update-param))))



(defund-inline glcp-config-update-term (term config)
  (declare (xargs :guard (glcp-config-p config)))
  (change-glcp-config config :top-level-term term))

(defthm param-bfr-of-glcp-config-update-term
  (equal (glcp-config->param-bfr (glcp-config-update-term term config))
         (glcp-config->param-bfr config))
  :hints(("Goal" :in-theory (enable glcp-config-update-term))))

(defthm glcp-config->overrides-of-glcp-config-update-term
  (equal (glcp-config->overrides (glcp-config-update-term term config))
         (glcp-config->overrides config))
  :hints(("Goal" :in-theory (enable glcp-config-update-term))))

(defthm glcp-config->top-level-term-of-glcp-config-update-term
  (equal (glcp-config->top-level-term (glcp-config-update-term term config))
         term)
  :hints(("Goal" :in-theory (enable glcp-config-update-term))))


