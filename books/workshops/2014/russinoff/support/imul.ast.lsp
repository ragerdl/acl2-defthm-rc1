

(funcdef Encode (slice) (block (declare enc 0) (switch slice (4 (assign enc (bits 6 2
 0))) ((5 6) (assign enc (bits 5 2
 0))) ((7 0) (assign enc (bits 0 2
 0))) ((1 2) (assign enc (bits 1 2
 0))) (3 (assign enc (bits 2 2
 0))) (t (assert (false$) Encode))) (return enc)))(funcdef Booth (x) (block (declare x35 (bits (ash x 1) 34
 0)) (declare a ()) (for ((declare k 0) (log< k 17) (+ k 1)) (block (assign a (as k (Encode (bits x35 (+ (* 2 k) 2) (* 2 k))) a)))) (return a)))(funcdef PartialProducts (m21 y) (block (declare pp ()) (for ((declare k 0) (log< k 17) (+ k 1)) (block (declare row 0) (switch (bits (ag k m21) 1 0) (2 (assign row (bits (ash y 1) 32
 0))) (1 (assign row y)) (t (assign row (bits 0 32
 0)))) (assign pp (as k (bits (if1 (bitn (ag k m21) 2) (lognot row) row) 32
 0) pp)))) (return pp)))(funcdef Align (bds pps) (block (declare sb ()) (declare psb ()) (for ((declare k 0) (log< k 17) (+ k 1)) (block (assign sb (as k (bitn (ag k bds) 2) sb)) (assign psb (as (+ k 1) (bitn (ag k bds) 2) psb)))) (declare tble ()) (for ((declare k 0) (log< k 17) (+ k 1)) (block (declare tmp (bits 0 66
 0)) (assign tmp (setbits tmp 67
 (+ (* 2 k) 32) (* 2 k) (ag k pps))) (if (log= k 0) (block (assign tmp (setbitn tmp 67
 33 (ag k sb))) (assign tmp (setbitn tmp 67
 34 (ag k sb))) (assign tmp (setbitn tmp 67
 35 (lognot1 (ag k sb))))) (block (assign tmp (setbitn tmp 67
 (- (* 2 k) 2) (ag k psb))) (assign tmp (setbitn tmp 67
 (+ (* 2 k) 33) (lognot1 (ag k sb)))) (assign tmp (setbitn tmp 67
 (+ (* 2 k) 34) 1)))) (assign tble (as k (bits tmp 63 0) tble)))) (return tble)))(funcdef Compress32 (in0 in1 in2) (block (declare out0 (logxor (logxor in0 in1) in2)) (declare out1 (logior (logior (logand in0 in1) (logand in0 in2)) (logand in1 in2))) (assign out1 (bits (ash out1 1) 63
 0)) (return (mv out0 out1))))(funcdef Compress42 (in0 in1 in2 in3) (block (declare temp (bits (ash (logior (logior (logand in1 in2) (logand in1 in3)) (logand in2 in3)) 1) 63
 0)) (declare out0 (logxor (logxor (logxor (logxor in0 in1) in2) in3) temp)) (declare out1 (logior (logand in0 (bits (lognot (logxor (logxor (logxor in0 in1) in2) in3)) 63
 0)) (logand temp (logxor (logxor (logxor in0 in1) in2) in3)))) (assign out1 (bits (ash out1 1) 63
 0)) (return (mv out0 out1))))(funcdef Sum (in) (block (declare A1 ()) (for ((declare i 0) (log< i 4) (+ i 1)) (block (block (declare temp-1) (declare temp-0) (mv-assign (temp-0 temp-1) (Compress42 (ag (* 4 i) in) (ag (+ (* 4 i) 1) in) (ag (+ (* 4 i) 2) in) (ag (+ (* 4 i) 3) in))) (assign A1 (as (+ (* 2 i) 0) temp-0 A1)) (assign A1 (as (+ (* 2 i) 1) temp-1 A1))))) (declare A2 ()) (for ((declare i 0) (log< i 2) (+ i 1)) (block (block (declare temp-1) (declare temp-0) (mv-assign (temp-0 temp-1) (Compress42 (ag (* 4 i) A1) (ag (+ (* 4 i) 1) A1) (ag (+ (* 4 i) 2) A1) (ag (+ (* 4 i) 3) A1))) (assign A2 (as (+ (* 2 i) 0) temp-0 A2)) (assign A2 (as (+ (* 2 i) 1) temp-1 A2))))) (declare A3 ()) (block (declare temp-1) (declare temp-0) (mv-assign (temp-0 temp-1) (Compress42 (ag 0 A2) (ag 1 A2) (ag 2 A2) (ag 3 A2))) (assign A3 (as 0 temp-0 A3)) (assign A3 (as 1 temp-1 A3))) (declare A4 ()) (block (declare temp-1) (declare temp-0) (mv-assign (temp-0 temp-1) (Compress32 (ag 0 A3) (ag 1 A3) (ag 16 in))) (assign A4 (as 0 temp-0 A4)) (assign A4 (as 1 temp-1 A4))) (return (bits (+ (ag 0 A4) (ag 1 A4)) 63
 0))))(funcdef Imul (s1 s2) (block (declare bd (Booth s1)) (declare pp (PartialProducts bd s2)) (declare tble (Align bd pp)) (declare prod (Sum tble)) (return prod)))(funcdef ImulTest (s1 s2) (block (declare spec_result (bits (* s1 s2) 63
 0)) (declare imul_result (Imul s1 s2)) (return (mv (log= spec_result imul_result) spec_result imul_result))))
