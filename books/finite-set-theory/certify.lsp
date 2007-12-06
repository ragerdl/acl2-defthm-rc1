; Contributed by Scott L. Burson; based on Makefile in this directory.

(in-package "ACL2")

(certify-book "total-ordering" 0)
:u

(defpkg "S"
  (set-difference-equal
   (union-eq '(PACK
               ORDINARYP
               <<
               <<-IRREFLEXIVITY
               <<-TRICHOTOMY
               <<-MUTUAL-EXCLUSION
               <<-TRANSITIVITY
               FAST-<<-TRICHOTOMY
               FAST-<<-MUTUAL-EXCLUSION
               FAST-<<-TRANSITIVITY
               FAST-<<-RULES
               SLOW-<<-RULES
               <<-RULES)
             (union-eq *acl2-exports*
                       *common-lisp-symbols-from-main-lisp-package*))
   '(union intersection subsetp add-to-set functionp = apply)))

(certify-book "set-theory" 1)
:u :u
