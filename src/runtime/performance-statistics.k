;;;
;;; performance-statistics.k
;;;

($provide! (emit-performance-statistics-macros)

  ($define! add-index
    ($lambda (n xs)
      ($if (null? xs)
        ()
        (cons (cons (car xs) n)
              (add-index (+ n 1) (cdr xs))))))

  ($define! perf-time-sections
    (add-index 0
      (list "lisp-gc"
            "blob-gc"
            "equal"
            "check-ptree"
            "system-call")))

  ($bind-private! perf-time-sections
    perf-time-sections)

  ($define! emit-performance-statistics-macros
    ($lambda ()
      (asm "%define perf_time_section_count"
        (length perf-time-sections))
      (for-each
        ($lambda ((name . index))
          (asm "%define"
            (asm-identifier "perf_time_section_" name)
            index))
        perf-time-sections))))
