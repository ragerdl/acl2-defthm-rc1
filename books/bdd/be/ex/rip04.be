@BE1

@invar
 (A1 B1 A2 B2 A3 B3 A4 B4)

@sub
CAR1 = 
(AND A1 B1)
CAR2 = 
(OR (AND (OR A2 B2) CAR1) (AND A2 B2))
CAR3 = 
(OR (AND (OR A3 B3) CAR2) (AND A3 B3))

@out
SOM1 = 
(EXOR A1 B1)
SOM2 = 
(EXOR A2 B2 CAR1)
SOM3 = 
(EXOR A3 B3 CAR2)
SOM4 = 
(EXOR A4 B4 CAR3)
COUT = 
(OR (AND (OR A4 B4) CAR3) (AND A4 B4))

@end


@BE2

@invar
 (A1 B1 A2 B2 A3 B3 A4 B4)

@sub
COUT1 = 
(AND B1 A1)
COUT2 = 
(OR (AND COUT1 B2) (AND COUT1 A2) (AND B2 A2))
COUT3 = 
(OR (AND COUT2 B3) (AND COUT2 A3) (AND B3 A3))

@out
SOM1 = 
(NOT (OR (AND (NOT A1) (NOT B1)) (AND A1 B1))) 
SOM2 = 
(NOT (OR (AND (OR (AND (NOT A2) (NOT B2)) (AND A2 B2)) (NOT COUT1)) (AND COUT1 (NOT (OR (AND (NOT A2) (NOT B2)) (AND A2 B2)))))) 
SOM3 = 
(NOT (OR (AND (OR (AND (NOT A3) (NOT B3)) (AND A3 B3)) (NOT COUT2)) (AND COUT2 (NOT (OR (AND (NOT A3) (NOT B3)) (AND A3 B3)))))) 
SOM4 = 
(NOT (OR (AND (OR (AND (NOT A4) (NOT B4)) (AND A4 B4)) (NOT COUT3)) (AND COUT3 (NOT (OR (AND (NOT A4) (NOT B4)) (AND A4 B4)))))) 
COUT = 
(OR (AND A4 COUT3) (AND B4 COUT3) (AND A4 B4)) 

@end
