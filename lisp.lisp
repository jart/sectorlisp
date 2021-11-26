;; (setq lisp-indent-function 'common-lisp-indent-function)
;; (paredit-mode)

;;                              ________
;;                             /_  __/ /_  ___
;;                              / / / __ \/ _ \
;;                             / / / / / /  __/
;;                            /_/ /_/ /_/\___/
;;     __    _________ ____     ________          ____
;;    / /   /  _/ ___// __ \   / ____/ /_  ____ _/ / /__  ____  ____ ____
;;   / /    / / \__ \/ /_/ /  / /   / __ \/ __ `/ / / _ \/ __ \/ __ `/ _ \
;;  / /____/ / ___/ / ____/  / /___/ / / / /_/ / / /  __/ / / / /_/ /  __/
;; /_____/___//____/_/       \____/_/ /_/\__,_/_/_/\___/_/ /_/\__, /\___/
;;                                                           /____/
;;
;; The LISP Challenge
;;
;; Pick your favorite programming language
;; Implement the tiniest possible LISP machine that
;; Bootstraps John Mccarthy'S metacircular evaluator below
;; Winning is defined by lines of code for scripting languages
;; Winning is defined by binary footprint for compiled languages
;;
;; Listed Projects
;;
;; - 512 bytes: https://github.com/jart/sectorlisp
;; - 13 kilobytes: https://t3x.org/klisp/
;; - 47 kilobytes: https://github.com/matp/tiny-lisp
;; - 150 kilobytes: https://github.com/JeffBezanson/femtolisp
;; - Send pull request to be listed here
;;
;; @see LISP From Nothing; Nils M. Holm; Lulu Press, Inc. 2020
;; @see Recursive Functions of Symbolic Expressions and Their
;;      Computation By Machine, Part I; John McCarthy, Massachusetts
;;      Institute of Technology, Cambridge, Mass. April 1960

;; NIL ATOM
;; ABSENCE OF VALUE AND TRUTH
NIL

;; CONS CELL
;; BUILDING BLOCK OF DATA STRUCTURES
(CONS NIL NIL)
(CONS (QUOTE X) (QUOTE Y))

;; REFLECTION
;; EVERYTHING IS AN ATOM OR NOT AN ATOM
(ATOM NIL)
(ATOM (CONS NIL NIL))

;; QUOTING
;; CODE IS DATA AND DATA IS CODE
(QUOTE (CONS NIL NIL))
(CONS (QUOTE CONS) (CONS NIL (CONS NIL NIL)))

;; LOGIC
;; BY WAY OF STRING INTERNING
(EQ (QUOTE A) (QUOTE A))
(EQ (QUOTE T) (QUOTE F))

;; FIND FIRST ATOM IN TREE
;; CORRECT RESULT OF EXPRESSION IS `A`
;; RECURSIVE CONDITIONAL FUNCTION BINDING
(((FF X)
  ((QUOTE T) (FF X)))
 (QUOTE ((X)
         ((ATOM X) X)
         ((QUOTE T) (FF (CAR X)))))
 (QUOTE ((A) B C)))

;; LISP IN LISP
;; WITH LANGUAGE REFORMS
(((ASSOC EVCON PAIRLIS EVLIS APPLY EVAL)
  ((QUOTE T)
   (EVAL (QUOTE (((FF X)
                  ((QUOTE T) (FF X)))
                 (QUOTE ((X)
                         ((ATOM X) X)
                         ((QUOTE T) (FF (CAR X)))))
                 (QUOTE ((A) B C))))
         ())))
 (QUOTE ((X Y)
         ((EQ X (CAR (CAR Y))) (CDR (CAR Y)))
         ((QUOTE T) (ASSOC X (CDR Y)))))
 (QUOTE ((C A)
         ((EVAL (CAR (CAR C)) A)
          (EVAL (CAR (CDR (CAR C))) A))
         ((QUOTE T) (EVCON (CDR C) A))))
 (QUOTE ((X Y A)
         ((EQ X ()) A)
         ((QUOTE T) (CONS (CONS (CAR X) (CAR Y))
                          (PAIRLIS (CDR X) (CDR Y) A)))))
 (QUOTE ((M A)
         ((EQ M ()) ())
         ((QUOTE T) (CONS (EVAL (CAR M) A)
                          (EVLIS (CDR M) A)))))
 (QUOTE ((FN X A)
         ((ATOM FN)
          ((() ((EQ FN (QUOTE CAR))  (CAR  (CAR X)))
               ((EQ FN (QUOTE CDR))  (CDR  (CAR X)))
               ((EQ FN (QUOTE ATOM)) (ATOM (CAR X)))
               ((EQ FN (QUOTE CONS)) (CONS (CAR X) (CAR (CDR X))))
               ((EQ FN (QUOTE EQ))   (EQ   (CAR X) (CAR (CDR X))))
               ((QUOTE T)            (APPLY (EVAL FN A) X A)))))
         ((QUOTE T)
          (EVCON (CDR FN) (PAIRLIS (CAR FN) X A)))))
 (QUOTE ((E A)
         ((EQ E ()) ())
         ((ATOM E) (ASSOC E A))
         ((ATOM (CAR E))
          ((() ((EQ (CAR E) (QUOTE QUOTE)) (CAR (CDR E)))
               ((QUOTE T) (APPLY (CAR E) (EVLIS (CDR E) A) A)))))
         ((QUOTE T) (APPLY (CAR E) (EVLIS (CDR E) A) A)))))
