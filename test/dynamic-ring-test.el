
;; Add source paths to load path so the tests can find the source files
;; Adapted from:
;; https://github.com/Lindydancer/cmake-font-lock/blob/47687b6ccd0e244691fb5907aaba609e5a42d787/test/cmake-font-lock-test-setup.el#L20-L27
(defvar dynamic-ring-test-setup-directory
  (if load-file-name
      (file-name-directory load-file-name)
    default-directory))

(dolist (dir '("." ".."))
  (add-to-list 'load-path
               (concat dynamic-ring-test-setup-directory dir)))

;;

(require 'dynamic-ring)
(require 'cl)

(ert-deftest dyn-ring-test ()
  ;; null constructor
  (should (make-dyn-ring))

  ;; dyn-ring-empty-p
  (should (dyn-ring-empty-p (make-dyn-ring)))
  (let ((ring (make-dyn-ring)))
    (dyn-ring-insert ring 1)
    (should-not (dyn-ring-empty-p ring)))

  ;; dyn-ring-size
  (should (= 0 (dyn-ring-size (make-dyn-ring))))
  (let ((ring (make-dyn-ring)))
    (dyn-ring-insert ring 1)
    (should (= 1 (dyn-ring-size ring))))

  ;; dyn-ring-head
  (should (null (dyn-ring-head (make-dyn-ring))))
  (let* ((ring (make-dyn-ring))
         (elem (dyn-ring-insert ring 1)))
    (should (equal elem (dyn-ring-head ring))))

  ;; dyn-ring-value
  (should (null (dyn-ring-value (make-dyn-ring))))
  (let ((ring (make-dyn-ring)))
    (dyn-ring-insert ring 1)
    (should (= 1 (dyn-ring-value ring)))))

(ert-deftest dyn-ring-segment-test ()
  ;; constructor
  (should (dyn-ring-make-segment 1))

  ;; dyn-ring-segment-value
  (should (= 1
             (dyn-ring-segment-value
              (dyn-ring-make-segment 1))))

  ;; dyn-ring-set-segment-value
  (let ((elem (dyn-ring-make-segment 1)))
    (dyn-ring-set-segment-value elem 2)
    (should (= 2
               (dyn-ring-segment-value elem))))

  ;; dyn-ring-segment-previous and dyn-ring-segment-next
  (let* ((ring (make-dyn-ring))
         (elem (dyn-ring-insert ring 1)))
    ;; TODO: should be a trivial ring rather than a non-ring
    (should (null (dyn-ring-segment-previous elem)))
    (should (null (dyn-ring-segment-next elem))))
  (let* ((ring (make-dyn-ring))
         (elem (dyn-ring-insert ring 1))
         (elem2 (dyn-ring-insert ring 2)))
    (should (equal elem2 (dyn-ring-segment-previous elem)))
    (should (equal elem2 (dyn-ring-segment-next elem)))
    (should (equal elem (dyn-ring-segment-previous elem2)))
    (should (equal elem (dyn-ring-segment-next elem2)))))

(ert-deftest dyn-ring-traverse-test ()
  ;; empty ring
  (let ((ring (make-dyn-ring))
        (memo (list)))
    (letf ((memofn (lambda (arg)
                     (push arg memo))))
      (should-not (dyn-ring-traverse ring memofn))
      (should (null memo))))

  ;; one-element ring
  (let* ((ring (make-dyn-ring))
         (memo (list)))
    (letf ((memofn (lambda (arg)
                     (push arg memo))))
      (dyn-ring-insert ring 1)
      (should (dyn-ring-traverse ring memofn))
      (should (equal memo (list 1)))))

  ;; two-element ring
  (let* ((ring (make-dyn-ring))
         (memo (list)))
    (letf ((memofn (lambda (arg)
                     (push arg memo))))
      (dyn-ring-insert ring 1)
      (dyn-ring-insert ring 2)
      (should (dyn-ring-traverse ring memofn))
      (should (equal memo (list 1 2)))))

  ;; 3-element ring
  (let* ((ring (make-dyn-ring))
         (memo (list)))
    (letf ((memofn (lambda (arg)
                     (push arg memo))))
      (dyn-ring-insert ring 1)
      (dyn-ring-insert ring 2)
      (dyn-ring-insert ring 3)
      (should (dyn-ring-traverse ring memofn))
      (should (equal memo (list 1 2 3))))))

(ert-deftest dyn-ring-traverse-collect-test ()
  ;; empty ring
  (let ((ring (make-dyn-ring)))
    (let ((result (dyn-ring-traverse-collect ring #'1+)))
      (should (null result))))

  ;; one-element ring
  (let ((ring (make-dyn-ring)))
    (dyn-ring-insert ring 1)
    (let ((result (dyn-ring-traverse-collect ring #'1+)))
      (should (equal result (list 2)))))

  ;; two-element ring
  (let* ((ring (make-dyn-ring)))
    (dyn-ring-insert ring 1)
    (dyn-ring-insert ring 2)
    (let ((result (dyn-ring-traverse-collect ring #'1+)))
      (should (equal result (list 2 3)))))

  ;; 3-element ring
  (let* ((ring (make-dyn-ring)))
    (dyn-ring-insert ring 1)
    (dyn-ring-insert ring 2)
    (dyn-ring-insert ring 3)
    (let ((result (dyn-ring-traverse-collect ring #'1+)))
      (should (equal result (list 2 3 4))))))

(ert-deftest dyn-ring-insert-test ()
  ;; empty ring
  (let ((ring (make-dyn-ring)))
    (should (dyn-ring-insert ring 1))
    (should (= 1 (dyn-ring-value ring)))
    ;; TODO: should be a trivial ring rather than a non-ring
    (should (null (dyn-ring-segment-previous (dyn-ring-head ring))))
    (should (null (dyn-ring-segment-next (dyn-ring-head ring)))))

  ;; one-element ring
  (let* ((ring (make-dyn-ring))
         (elem1 (dyn-ring-insert ring 1)))
    (let ((new (dyn-ring-insert ring 2)))
      (should new)
      (should (= 2 (dyn-ring-value ring)))
      (should (eq (dyn-ring-segment-previous new)
                  elem1))
      (should (eq (dyn-ring-segment-next new)
                  elem1))
      (should (eq (dyn-ring-segment-previous elem1)
                  new))
      (should (eq (dyn-ring-segment-next elem1)
                  new))))

  ;; two-element ring
  (let* ((ring (make-dyn-ring))
         (elem1 (dyn-ring-insert ring 1))
         (elem2 (dyn-ring-insert ring 2)))
    (let ((new (dyn-ring-insert ring 3)))
      (should new)
      (should (= 3 (dyn-ring-value ring)))
      (should (eq (dyn-ring-segment-previous new)
                  elem1))
      (should (eq (dyn-ring-segment-next new)
                  elem2))
      (should (eq (dyn-ring-segment-previous elem1)
                  elem2))
      (should (eq (dyn-ring-segment-next elem1)
                  new))
      (should (eq (dyn-ring-segment-previous elem2)
                  new))
      (should (eq (dyn-ring-segment-next elem2)
                  elem1)))))

(ert-deftest dyn-ring-rotate-test ()
  ;; empty ring
  (let ((ring (make-dyn-ring)))
    (should (null (dyn-ring-rotate-left ring)))
    (should (null (dyn-ring-rotate-right ring))))

  ;; 1-element ring
  (let* ((ring (make-dyn-ring))
         (segment (dyn-ring-insert ring 1)))
    ;; TODO: this should be a trivial ring rather than
    ;; a non-ring
    ;; (should (eq segment (dyn-ring-rotate-left ring)))
    ;; (should (eq segment (dyn-ring-rotate-right ring)))
    (should (null (dyn-ring-rotate-left ring)))
    (should (null (dyn-ring-rotate-right ring))))

  ;; 2-element ring
  (let* ((ring (make-dyn-ring))
         (seg1 (dyn-ring-insert ring 1))
         (seg2 (dyn-ring-insert ring 2)))
    (should (eq seg1 (dyn-ring-rotate-left ring)))
    (should (eq seg2 (dyn-ring-rotate-left ring)))
    (should (eq seg1 (dyn-ring-rotate-right ring)))
    (should (eq seg2 (dyn-ring-rotate-right ring))))

  ;; 3-element ring
  (let* ((ring (make-dyn-ring))
         (seg1 (dyn-ring-insert ring 1))
         (seg2 (dyn-ring-insert ring 2))
         (seg3 (dyn-ring-insert ring 3)))
    (should (eq seg1 (dyn-ring-rotate-left ring)))
    (should (eq seg2 (dyn-ring-rotate-left ring)))
    (should (eq seg3 (dyn-ring-rotate-left ring)))
    (should (eq seg2 (dyn-ring-rotate-right ring)))
    (should (eq seg1 (dyn-ring-rotate-right ring)))
    (should (eq seg3 (dyn-ring-rotate-right ring)))))

(ert-deftest dyn-ring-delete-test ()
  ;; empty ring
  (let ((ring (make-dyn-ring))
        (segment (dyn-ring-make-segment 1)))
    (should (null (dyn-ring-delete ring segment)))
    (should (dyn-ring-empty-p ring)))

  ;; 1-element ring
  (let* ((ring (make-dyn-ring))
         (segment (dyn-ring-insert ring 1)))
    (should (dyn-ring-delete ring segment))
    (should (dyn-ring-empty-p ring)))

  ;; 2-element ring
  (let* ((ring (make-dyn-ring))
         (seg1 (dyn-ring-insert ring 1))
         (seg2 (dyn-ring-insert ring 2)))
    ;; delete head
    (should (dyn-ring-delete ring seg2))
    (should (= 1 (dyn-ring-size ring)))
    (should (eq seg1 (dyn-ring-head ring)))
    ;; TODO: trivial ring
    ;; (should (eq (dyn-ring-segment-next seg1) seg1))
    ;; (should (eq (dyn-ring-segment-previous seg1) seg1))
    )
  (let* ((ring (make-dyn-ring))
         (seg1 (dyn-ring-insert ring 1))
         (seg2 (dyn-ring-insert ring 2)))
    ;; delete non-head
    (should (dyn-ring-delete ring seg1))
    (should (= 1 (dyn-ring-size ring)))
    (should (eq seg2 (dyn-ring-head ring)))
    ;; TODO: trivial ring
    ;; (should (eq (dyn-ring-segment-next seg2) seg2))
    ;; (should (eq (dyn-ring-segment-previous seg2) seg2))
    )

  ;; 3-element ring
  (let* ((ring (make-dyn-ring))
         (seg1 (dyn-ring-insert ring 1))
         (seg2 (dyn-ring-insert ring 2))
         (seg3 (dyn-ring-insert ring 3)))
    ;; delete head
    (should (dyn-ring-delete ring seg3))
    (should (= 2 (dyn-ring-size ring)))
    (should (eq seg2 (dyn-ring-head ring)))
    (should (eq (dyn-ring-segment-next seg2) seg1))
    (should (eq (dyn-ring-segment-previous seg2) seg1))
    (should (eq (dyn-ring-segment-next seg1) seg2))
    (should (eq (dyn-ring-segment-previous seg1) seg2)))
  (let* ((ring (make-dyn-ring))
         (seg1 (dyn-ring-insert ring 1))
         (seg2 (dyn-ring-insert ring 2))
         (seg3 (dyn-ring-insert ring 3)))
    ;; delete right
    (should (dyn-ring-delete ring seg2))
    (should (= 2 (dyn-ring-size ring)))
    (should (eq seg3 (dyn-ring-head ring)))
    (should (eq (dyn-ring-segment-next seg3) seg1))
    (should (eq (dyn-ring-segment-previous seg3) seg1))
    (should (eq (dyn-ring-segment-next seg1) seg3))
    (should (eq (dyn-ring-segment-previous seg1) seg3)))
  (let* ((ring (make-dyn-ring))
         (seg1 (dyn-ring-insert ring 1))
         (seg2 (dyn-ring-insert ring 2))
         (seg3 (dyn-ring-insert ring 3)))
    ;; delete left
    (should (dyn-ring-delete ring seg1))
    (should (= 2 (dyn-ring-size ring)))
    (should (eq seg3 (dyn-ring-head ring)))
    (should (eq (dyn-ring-segment-next seg3) seg2))
    (should (eq (dyn-ring-segment-previous seg3) seg2))
    (should (eq (dyn-ring-segment-next seg2) seg3))
    (should (eq (dyn-ring-segment-previous seg2) seg3))))

