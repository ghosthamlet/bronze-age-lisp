;;
;; 10-levenshtein.k
;;
;; Levenshtein distance of two strings.
;;
;; Benchmark for (apply ...), vector indexing and string indexing.
;;

($define! $memoize-in-vector!
  ($vau (symbol index cache) denv
    ($define! base (eval symbol denv))
    ($define! index (eval index denv))
    ($define! cache (eval cache denv))
    ((wrap $set!)
      denv
      symbol
      ($lambda args
        ($define! i (apply index args))
        ($when (inert? (vector-ref cache i))
          (vector-set! cache i (apply base args)))
        (vector-ref cache i)))))

($define! levenshtein-distance
  ($lambda (a b)
    ($define! m (string-length a))
    ($define! n (string-length b))
    ($define! lev
      ($lambda (i j)
        ($cond
          ((=? 0 i) j)
          ((=? 0 j) i)
          (#t       (min (+ 1 (lev (- i 1) j))
                         (+ 1 (lev i (- j 1)))
                         (+ ($if (char=? (string-ref a (- i 1)) (string-ref b (- j 1)))
                              0 1)
                            (lev (- i 1) (- j 1))))))))
    ($memoize-in-vector!
      lev
      ($lambda (i j) (+ i (* (+ 1 m) j)))
      (make-vector (* (+ 1 m) (+ 1 n)) #inert))
    (lev m n)))

($define! text-1
  "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed
   do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
($define! text-2
  "Ut enim ad minim veniam, quis nostrud exercitation ullamco
   laboris nisi ut aliquip ex ea commodo consequat.")

(write (levenshtein-distance text-1 text-2))
(newline)
