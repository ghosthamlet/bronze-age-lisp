;;;
;;; lists.k
;;;
;;; Built-in list applicatives.
;;;

($provide! ()
  ($define! $bind!
    ($vau (symbol label rel) denv
      (bind-ground! symbol
        (make-bounded-applicative
          (list 2 2)
          (list label)
          (list symbol (make-nonlisp-value rel))))))

  ($bind! assoc "app_assoc" "rn_equal")
  ($bind! assq "app_assoc" "rn_eq")
  ($bind! member? "app_member" "rn_equal")
  ($bind! memq? "app_member" "rn_eq"))

;;
;; Implementation of (append ...), based on Kernel Report.
;; Two-argument applicative call (append X Y) is handled
;; in lists.asm.
;;
($defun-privates!
  (general-append lss
    ($if (null? lss)
     ()
     ($sequence
       ($define! (#ignore #ignore a c) (get-list-metrics lss))
       ($if (>? c 0)
         ($let1 cycle (append-aux c (list-tail lss a) ())
           ($when (pair? cycle)
             (encycle! cycle 0 (length cycle)))
           (append-aux a lss cycle))
         (append-aux (- a 1) lss (list-ref lss (- a 1)))))))
  (append-aux (k lss tail) ; prepend k elmts of lss onto tail
    ($if (>? k 0)
      (append (car lss)
              (append-aux (- k 1) (cdr lss) tail))
      tail)))

;; list-neighbors from kernel report
;;
($define-ground-lambda! list-neighbors (ls)
  ($define! aux
    ($lambda (ls n) ; get n sets of neighbors from ls
      ($if (>? n 0)
           (cons (list (car ls) (cadr ls))
                 (aux (cdr ls) (- n 1)))
           ())))
  ($let (((p #ignore a c) (get-list-metrics ls)))
    ($if (=? c 0)
         (aux ls (- a 1))
         ($let ((ls (aux ls p)))
           (encycle! ls a c)
           ls))))

;; reduce from Kernel Report
;;
($defun-privates!
  (reduce-acyclic (ls bin id)
    ($cond ((null? ls)       id)
           ((null? (cdr ls)) (car ls))
           (#t
             (bin (car ls)
                  (reduce-acyclic (cdr ls) bin id)))))
  (reduce-n (ls bin n)
    ($if (=? n 1)
         (car ls)
         (bin (car ls)
              (reduce-n (cdr ls) bin (- n 1))))))

($define-ground-wrapvau! reduce (ls bin id . opt) env
  ($define! fixenv
    ($lambda (appv)
      ($lambda x (apply appv x env))))
  ($define! bin (fixenv bin))
  ($let (((p n a c) (get-list-metrics ls)))
    ($if (=? c 0)
         (reduce-acyclic ls bin id)
         ($sequence
           ($define! (pre in post) (map fixenv opt))
           ($define! reduced-cycle
             (post (reduce-n (map pre (list-tail ls a))
                             in
                             c)))
           ($if (=? a 0)
                reduced-cycle
                (bin (reduce-n ls bin a)
                     reduced-cycle))))))

;; append! adapted from Kernel Report.
;;
($define-ground-lambda! append! lss
  (for-each
    ($lambda ((a b)) (set-cdr! (list-tail a (- (length a) 1)) b))
    (list-neighbors (filter ($lambda (x) (not? (null? x))) lss))))

;; copy-es adapted from Kernel Report, but using
;; assq instead of assoc.
;;
;; Inefficient implementation.
;;
($define-ground-lambda! copy-es (x)
  ($define! aux
    ($lambda (x alist)
      ($if (pair? x)
        ($let ((record (assq x alist)))
          ($if (pair? record)
            (list (cdr record) alist)
            ($let* ((y         (cons () ()))
                    (alist     (cons (cons x y) alist))
                    ((z alist) (aux (car x) alist))
                    (#ignore   (set-car! y z))
                    ((z alist) (aux (cdr x) alist))
                    (#ignore   (set-cdr! y z)))
              (list y alist))))
        (list x alist))))
  (car (aux x ())))

;; list-set! is from klisp (list_setB() in klisp/src/kgpair_mut.c)
;;  TODO: large index for cyclic lists?
($define-ground-lambda! list-set! (xs k v)
  (set-car! (list-tail xs k) v))

;; list-copy is from SRFI-1
;;
($define-ground-lambda! list-copy (xs)
  (map list* xs))

;; take from SRFI-1
($define-ground-lambda! take (xs n)
  ($if (positive? n)
    (cons (car xs) (take (cdr xs) (- n 1)))
    ()))
