(READ)AAA
(READ)(1 (2 3) 4)
(READ)

  AAA
(READ)

  (1 (2 3) 4)
(CAR (READ))(1 (2 3) 4)
(CDR (READ))(1 (2 3) 4)
(CONS (READ) (CONS (QUOTE A) NIL))B
(CONS (READ) (CONS (QUOTE A) NIL))(1 (2 3) 4)
(ATOM (READ))A
(ATOM (READ))(1 2)
(EQ (QUOTE A) (READ))A
(EQ (QUOTE B) (READ))A
(PRINT (QUOTE A))
(PRINT (QUOTE (1 2)))
((LAMBDA () ())
 (PRINT (QUOTE A))
 (PRINT (QUOTE B))
 (PRINT)
 (PRINT (QUOTE C))
 (PRINT (QUOTE (1 2 3)))
 (PRINT))
(PRINT (READ))AAA
(PRINT (READ))(1 (2 3) 4)
(PRINT)
(PRINT (PRINT))
(PRINT (PRINT (QUOTE A)))
((LAMBDA (LOOP) (LOOP LOOP))
 (QUOTE (LAMBDA (LOOP)
          ((LAMBDA () ())
           (PRINT (QUOTE >))
           (PRINT (CONS (QUOTE INPUT) (CONS (READ) NIL)))
           (PRINT)
           (LOOP LOOP)))))
A
B
C
(1 2)
(1 (2 3) 4)
