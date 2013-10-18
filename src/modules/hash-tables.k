;;;
;;; hash-tables.k
;;;
;;; Hash tables (in the SRFI-69 style) and hash functions (lisp part).
;;;
;;; Each hash table contains
;;;
;;;  vector        ... vector of buckets
;;;                      Each bucket is a list of (key . value) pairs.
;;;
;;;  length        ... number of items stored
;;;
;;;  hashf         ... hash function
;;;
;;;  list_lookup   ... native procedure searching in one bucket
;;;
;;;  eq_proc       ... native equality procedure
;;;
;;;  reconstructor ... reconstructor applicative
;;;                      This function creates a fresh, empty hash table
;;;                      which inherits the hash function and equality
;;;                      predicate. The bucket count of the new table
;;;                      is given by the function parameter.
;;;

($bind-private! make-eq-hash-table
  (make-bounded-applicative
    (list 3 3) (list "app_make_hash_table.eq") ()))

($bind-private! make-equal-hash-table
  (make-bounded-applicative
    (list 3 3) (list "app_make_hash_table.equal") ()))

($bind-private! make-user-equivalence-hash-table
  (make-bounded-applicative
    (list 3 3) (list "app_make_hash_table.user") ()))

($bind-private! hash-table-lookup
  (make-bounded-applicative
    (list 2 2) (list "app_hash_table_lookup.A2") ()))

($bind-private! replace-hash-table!
  (make-bounded-applicative
    (list 2 2) (list "app_replace_hash_tableB.A2") ()))

($bind-private! adjust-hash-table-length!
  (make-bounded-applicative
    (list 2 2) (list "app_adjust_hash_table_lengthB.A2") ()))

($bind-private! hash-table-max-bucket-size 10)

(for-each
  ($lambda (f)
    ($define! s (symbol-append* "hash-table-" f))
    (bind-private! s
      (make-bounded-applicative
        (list 1 1)
        (list (string-append* "app_hash_table_" (asm-identifier f)))
        ())))
  ($quote* vector reconstructor bucket-count))

($bind-ground! hash-table-length
  (make-bounded-applicative
    (list 1 1) (list "app_hash_table_length") ()))

;;
;; Construction and rehashing.
;;
($define-ground-lambda! make-hash-table args
  ($define! (eqp hashfgen)
    ($match args
      (()
        (list eq? make-hash-function))
      ((eqp)
        (list eqp make-hash-function))
      ((eqp hashf)
        (list eqp ($lambda (n) ($lambda (x) (mod (hashf x) n)))))
      (#ignore
        ($error make-hash-table "Invalid argument structure." args))))
   ($define! ctor
     ($cond
       ((eq? eq? eqp)
         make-eq-hash-table)
       ((eq? equal? eqp)
         make-equal-hash-table)
       ((applicative? eqp)
         ($lambda (v g r)
           (make-user-equivalence-hash-table v (cons g (unwrap eqp)) r)))
       (#t
         ($error make-hash-table "Invalid equality predicate." eqp))))
   ($define! make
     ($lambda (n)
       (ctor (make-vector n ()) (hashfgen n) make)))
   (make 32))

($define-private-lambda! grow-hash-table! (h)
  ($define! new-n (* 2 (hash-table-bucket-count h)))
  ($define! new-h ((hash-table-reconstructor h) new-n))
  (hash-table-for-each
    ($lambda (k v) (hash-table-set-nogrow! new-h k v))
    h)
  (replace-hash-table! h new-h))

;;
;; single element operations
;;

($define-ground-lambda! hash-table-exists? (h . ks)
  (apply and?
    (map ($lambda (k)
           (pair? (cdr (hash-table-lookup h k))))
         ks)))

($define-ground-lambda! hash-table-ref (h k)
  ($match (cdr (hash-table-lookup h k))
    (((#ignore . v) . #ignore) v)
    (()                        ($error hash-table-ref "Key not found." h k))))

($define-ground-lambda! hash-table-set! (h k v)
  ($define! (i . t) (hash-table-lookup h k))
  ($if (pair? t)
    (set-cdr! (car t) v)
    ($sequence
      (adjust-hash-table-length! h +1)
      (vector-set! (hash-table-vector h)
        i
        (cons (cons k v) (vector-ref (hash-table-vector h) i)))
      ($when (>? (length (vector-ref (hash-table-vector h) i))
                 hash-table-max-bucket-size)
        (grow-hash-table! h)))))

($define-ground-lambda! hash-table-set-nogrow! (h k v)
  ($define! (i . t) (hash-table-lookup h k))
  ($cond
    ((pair? t)
      (set-cdr! (car t) v))
    ((>? (length (vector-ref (hash-table-vector h) i))
         hash-table-max-bucket-size)
      ($error1 hash-table-set!
        "Too many keys with colliding hash values."
        (map car (vector-ref (hash-table-vector h) i))))
    (#t
      (adjust-hash-table-length! h +1)
      (vector-set! (hash-table-vector h)
        i
        (cons (cons k v) (vector-ref (hash-table-vector h) i))))))

($define-ground-lambda! hash-table-delete! (h k)
  ($define! (i . t) (hash-table-lookup h k))
  ($unless (null? t)
    (adjust-hash-table-length! h -1)
    ($cond
      ((pair? (cdr t))
        (set-car! t (cadr t))
        (set-cdr! t (cddr t)))
      (#t
        ($let1 r (vector-ref (hash-table-vector h) i)
          ($unless (eq? r t)
            (set-car! t (caar r)))
          (vector-set! (hash-table-vector h)
                        i
                        (cdr r)))))))

;;
;; whole contents manipulation and high level constructors
;;

($define-ground-wrapvau! hash-table-for-each (f h) denv
  ($define! g
    ($lambda ((x . y)) (apply f (list x y) denv)))
  (vector-for-each
    ($lambda (b) (for-each g b))
    (hash-table-vector h)))

($define-ground-lambda! hash-table-fold (h f i)
  ($define! e (get-current-environment))
  ($define! g ($lambda ((x . y)) ($set! e i (apply f (list x y i)))))
  (vector-for-each
    ($lambda (b) (for-each g b))
    (hash-table-vector h))
  i)

($define-ground-lambda! hash-table-keys (h)
  (hash-table-fold h ($lambda (k v a) (cons k a)) ()))

($define-ground-lambda! hash-table-values (h)
  (hash-table-fold h ($lambda (k v a) (cons v a)) ()))

($define-ground-lambda! hash-table->alist (h)
  (apply append (vector->list (hash-table-vector h))))

($define-ground-lambda! alist->hash-table (alist . args)
  ($define! h (apply make-hash-table args))
  (for-each
    ($lambda ((k . v)) (hash-table-set! h k v))
    alist)
  h)

($define-ground-lambda! hash-table a
  ($define! h (make-hash-table))
  ($define! loop
    ($case-lambda
      (((k v . t)) (hash-table-set! h k v) (loop t))
      ((())        h)
      (#ignore     ($error1 hash-table "Invalid argument structure." a))))
  (loop a))

