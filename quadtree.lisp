;;; quadtree.lisp --- for spatial indexing and stuff

;; Copyright (C) 2011, 2012  David O'Toole

;; Author: David O'Toole <dto@gnu.org>
;; Keywords: 

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(in-package :blocky)

(defvar *quadtree* nil)

(defvar *world* nil
"The current world object. Only one may be active at a time. See also
worlds.lisp. Sprites and cells are free to send messages to `*world*'
at any time, because `*world*' is always bound to the world containing
the object when the method is run.")

(defmacro with-quadtree (quadtree &rest body)
  `(let* ((*quadtree* ,quadtree))
       ,@body))

(defvar *quadtree-depth* 0)

(defparameter *default-quadtree-depth* 9) 
 
(defstruct quadtree 
  objects bounding-box level
  southwest northeast northwest southeast)

(defmethod print-object ((tree blocky::quadtree) stream)
  (format stream "#<BLOCKY:QUADTREE count: ~S>"
	  (length (quadtree-objects tree))))

(defun leafp (node)
  ;; testing any quadrant will suffice
  (null (quadtree-southwest node)))

(defun bounding-box-contains (box0 box1)
  (destructuring-bind (top0 left0 right0 bottom0) box0
    (destructuring-bind (top1 left1 right1 bottom1) box1
      (and (<= top0 top1)
	   (<= left0 left1)
	   (>= right0 right1)
	   (>= bottom0 bottom1)))))

(defun scale-bounding-box (box factor)
  (destructuring-bind (top left right bottom) box
    (let ((margin-x (* (- right left)
		       (- factor 1.0)))
	  (margin-y (* (- bottom top)
		       (- factor 1.0))))
      (values (- top margin-y)
	      (- left margin-x)
	      (+ right margin-x)
	      (+ bottom margin-y)))))

(defun valid-bounding-box (box)
  (and (listp box)
       (= 4 (length box))
       (destructuring-bind (top left right bottom) box
	 (and (<= left right) (<= top bottom)))))

(defun northeast-quadrant (bounding-box)
  (assert (valid-bounding-box bounding-box))
  (destructuring-bind (top left right bottom) bounding-box
    (list top (float (/ (+ left right) 2))
	  right (float (/ (+ top bottom) 2)))))

(defun southeast-quadrant (bounding-box)
  (assert (valid-bounding-box bounding-box))
  (destructuring-bind (top left right bottom) bounding-box
    (list (float (/ (+ top bottom) 2)) (float (/ (+ left right) 2))
	  right bottom)))

(defun northwest-quadrant (bounding-box)
  (assert (valid-bounding-box bounding-box))
  (destructuring-bind (top left right bottom) bounding-box
    (list top left
	  (float (/ (+ left right) 2)) (float (/ (+ top bottom) 2)))))

(defun southwest-quadrant (bounding-box)
  (assert (valid-bounding-box bounding-box))
  (destructuring-bind (top left right bottom) bounding-box
    (list (float (/ (+ top bottom) 2)) left
	  (float (/ (+ left right) 2)) bottom)))

(defun quadtree-process (bounding-box processor &optional (node *quadtree*))
  (assert (quadtree-p node))
  (assert (valid-bounding-box bounding-box))
  (assert (functionp processor))
  (when (bounding-box-contains (quadtree-bounding-box node) bounding-box)
    (when (not (leafp node))
      (let ((*quadtree-depth* (1+ *quadtree-depth*)))
	(quadtree-process bounding-box processor (quadtree-northwest node))
	(quadtree-process bounding-box processor (quadtree-northeast node))
	(quadtree-process bounding-box processor (quadtree-southwest node))
	(quadtree-process bounding-box processor (quadtree-southeast node))))
    (funcall processor node)))

(defun build-quadtree (bounding-box0 &optional (depth *default-quadtree-depth*))
  (assert (plusp depth))
  (assert (valid-bounding-box bounding-box0))
  (let ((bounding-box (mapcar #'float bounding-box0)))
    (decf depth)
    (if (zerop depth)
	(make-quadtree :bounding-box bounding-box)
	(make-quadtree :bounding-box bounding-box
		       :northwest (build-quadtree (northwest-quadrant bounding-box) depth)
		       :northeast (build-quadtree (northeast-quadrant bounding-box) depth)
		       :southwest (build-quadtree (southwest-quadrant bounding-box) depth)
		       :southeast (build-quadtree (southeast-quadrant bounding-box) depth)))))

(defun quadtree-search (bounding-box &optional (node *quadtree*))
  "Return the smallest quadrant enclosing BOUNDING-BOX at or below
NODE, if any."
  (assert (quadtree-p node))
  (assert (valid-bounding-box bounding-box))
  ;; (message "~A ~A Searching quadrant ~S for bounding box ~S" 
  ;; 	   *quadtree-depth* (make-string (1+ *quadtree-depth*) :initial-element (character "."))
  ;; 	   (quadtree-bounding-box node) bounding-box)
  (when (bounding-box-contains (quadtree-bounding-box node) bounding-box)
    ;; ok, it's in the overall bounding-box.
    (if (leafp node)
	;; there aren't any quadrants to search.
	node
	(or
	 ;; search the quadrants.
	 (let ((*quadtree-depth* (1+ *quadtree-depth*)))
	   (or (quadtree-search bounding-box (quadtree-northwest node))
	       (quadtree-search bounding-box (quadtree-northeast node))
	       (quadtree-search bounding-box (quadtree-southwest node))
	       (quadtree-search bounding-box (quadtree-southeast node))))
	 ;; none of them are suitable. stay here
	 node))))

(defun quadtree-insert (object &optional (tree *quadtree*))
  (let ((node0
	  (quadtree-search 
	   (multiple-value-list 
	    (bounding-box object))
	   tree)))
    (let ((node (or node0 tree)))
      ;; (message "Inserting ~S ~S"
      ;; 	       (get-some-object-name object) 
      ;; 	       (object-address-string object))
      ;; (assert (not (find (find-object object)
      ;; 			 (quadtree-objects node)
      ;; 			 :test 'eq)))
      (pushnew (find-object object)
	       (quadtree-objects node)
	       :test 'eq)
      ;; save pointer to node so we can avoid searching when it's time
      ;; to delete (i.e. move) the object later.
      (blocky:set-field-value :quadtree-node object node)
      (assert (find (find-object object)
		    (quadtree-objects node)
		    :test 'eq)))))

(defun quadtree-delete (object0 &optional (tree *quadtree*))
  (let ((object (find-object object0)))
    ;; grab the cached quadtree node
    (let ((node (or (field-value :quadtree-node object) tree)))
      (assert node)
      (assert (find object
      		    (quadtree-objects node)
      		    :test 'eq))
      (setf (quadtree-objects node)
	    (delete object (quadtree-objects node) :test 'eq))
      (set-field-value :quadtree-node object nil)
      (assert (not (find object
			 (quadtree-objects node)
			 :test 'eq))))))

(defun quadtree-insert-maybe (object &optional (tree *quadtree*))
  (when tree
    (quadtree-insert object tree)))

(defun quadtree-delete-maybe (object &optional (tree *quadtree*))
  (when (and tree (field-value :quadtree-node object))
    (quadtree-delete object tree)))

(defun quadtree-map-collisions (bounding-box processor &optional (tree *quadtree*))
  (assert (functionp processor))
  (assert (valid-bounding-box bounding-box))
  (quadtree-process
   bounding-box
   #'(lambda (node)
       (dolist (object (quadtree-objects node))
	 (when (colliding-with-bounding-box object bounding-box)
	   (funcall processor object))))
   tree))

(defun quadtree-collide (object &optional (tree *quadtree*))
  (quadtree-map-collisions 
   (multiple-value-list (bounding-box object))
   #'(lambda (thing)
       (when (and (field-value :collision-type thing)
		  (colliding-with object thing)
		  (not (object-eq object thing)))
	 (with-quadtree tree
	   (collide object thing))))
   tree))

(defun find-bounding-box (objects)
  ;; calculate the bounding box of a list of objects
  (assert (not (null objects)))
  (labels ((left (thing) (field-value :x thing))
	   (right (thing) (+ (field-value :x thing)
			     (field-value :width thing)))
	   (top (thing) (field-value :y thing))
	   (bottom (thing) (+ (field-value :y thing)
			      (field-value :height thing))))
    ;; let's find the bounding box.
    (values (reduce #'min (mapcar #'top objects))
	    (reduce #'min (mapcar #'left objects))
	    (reduce #'max (mapcar #'right objects))
	    (reduce #'max (mapcar #'bottom objects)))))

(defun quadtree-fill (set &optional (quadtree *quadtree*))
  (let ((objects (etypecase set
		   (list set)
		   (hash-table (loop for object being the hash-keys in set collect object)))))
    (dolist (object objects)
;      (message "Filling ~S into quadtree" object)
      (set-field-value :quatree-node object nil)
      (quadtree-insert object quadtree))))

(defun quadtree-show (tree &optional object)
  (when tree
      ;; (dolist (ob (quadtree-objects tree))
      ;; 	(multiple-value-bind (top left right bottom) 
      ;; 	    (bounding-box ob)
      ;; 	  (draw-string (prin1-to-string *quadtree-depth*)
      ;; 		       left top
      ;; 		       :color "yellow")))
      (let ((bounding-box (quadtree-bounding-box tree)))
	(destructuring-bind (top left right bottom) bounding-box
	  (if (null object)
	      (draw-box (+ left 10) (+ top 10) (- right left 10) (- bottom top 10)
			:color "magenta"
			:alpha 0.1)
	      (when (colliding-with-rectangle 
		     object top left (- right left) (- bottom top))
		(draw-box left top (- right left) (- bottom top)
			  :color "cyan"
			  :alpha 0.2)))))
      (let ((*quadtree-depth* (1+ *quadtree-depth*)))
	(quadtree-show (quadtree-northeast tree) object)
	(quadtree-show (quadtree-northwest tree) object)
	(quadtree-show (quadtree-southeast tree) object)
	(quadtree-show (quadtree-southwest tree) object))))

;;; quadtree.lisp ends here
