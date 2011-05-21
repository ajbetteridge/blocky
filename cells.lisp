;;; cells.lisp --- defining in-game objects

;; Copyright (C) 2008, 2009, 2010, 2011  David O'Toole

;; Author: David O'Toole ^dto@gnu.org
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
;; along with this program.  If not, see ^http://www.gnu.org/licenses/.

;;; Code:

(in-package :ioforms)

(defblock cell 
  (type :initform :cell)
  (row :documentation "When non-nil, the current row location of the cell.")
  (column :documentation "When non-nil, the current column of the cell.")
  (name :initform nil :documentation "The name of this cell.")
  (description :initform nil :documentation "A description of the cell.") 
  (categories :initform nil :documentation "List of category keyword symbols."))

;;; Cell categories

(define-method in-category cell (category)
  "Return non-nil if this cell is in the specified CATEGORY.

Cells may be placed into categories that influence their processing by
the engine. The field `^categories' is a set of keyword symbols; if a
symbol `:foo' is in the list, then the cell is in the category `:foo'.

Although a game built on IOFORMS can define whatever categories are
needed, certain base categories are built-in and have a fixed
interpretation:

 -    :obstacle --- Blocks movement and causes collisions
 -    :ephemeral --- This cell is not preserved when exiting a world.
 -    :light-source --- This object casts light. 
 -    :opaque --- Blocks line-of-sight, casts shadows. 
"
  (member category ^categories))

(define-method add-category cell (category)
  "Add this cell to the specified CATEGORY."
  (pushnew category ^categories))

(define-method delete-category cell (category)
  "Remove this cell from the specified CATEGORY."
  (setf ^categories (remove category ^categories)))

;;; Locating the cell in grid space

(define-method is-grid-located cell ()
  "Returns non-nil if this cell is located somewhere on the grid."
  (and (integerp ^row) (integerp ^column)))

(define-method grid-coordinates cell ()
  (values ^row ^column))

(define-method xy-coordinates cell ()
  (values (* ^column (field-value :grid-size *world*))
	  (* ^row (field-value :grid-size *world*))))

(define-method coordinates cell ()
  (multiple-value-bind (x y) (xy-coordinates self)
    (values x y 0)))

;; (define-method viewport-coordinates cell ()
;;   "Return as values X,Y the world coordinates of CELL."
;;   (assert (and ^row ^column))
;;   (get-viewport-coordinates (field-value :viewport *world*)
;;                             ^row ^column))

;; (define-method image-coordinates cell ()
;;   "Return as values X,Y the viewport image coordinates of CELL."
;;   (assert (and ^row ^column))
;;   (get-image-coordinates (field-value :viewport *world*)
;;                          ^row ^column))

;; (define-method screen-coordinates cell ()
;;   "Return as values X,Y the screen coordinates of CELL."
;;   (assert (and ^row ^column))
;;   (get-screen-coordinates (field-value :viewport *world*)
;; 			  ^row ^column))

;;; Convenience macro for defining cells.

(defmacro defcell (name &body args)
  "Define a cell named NAME, with the fields ARGS as in a normal
prototype declaration. This is a convenience macro for defining new
cells."
  `(define-prototype ,name (:parent =cell=)
     ,@args))

;;; Cell death

(define-method die cell ()
  (delete-cell *world* self ^row ^column))

;;; Cell movement

(define-method move-to-grid cell (r c)
  (delete-cell *world* self ^row ^column)
  (drop-cell *world* self r c))

(define-method move-to cell (x y &optional z)
  (assert (and (integerp x) (integerp y)))
  (with-field-values (grid-size) *world*
    (let ((nearest-row (round y grid-size))
	  (nearest-column (round x grid-size)))
      (move-to-grid self nearest-row nearest-column))))

(define-method move cell (direction &optional (distance 1) ignore-obstacles)
  "Move this cell one step in DIRECTION on the grid. If
IGNORE-OBSTACLES is non-nil, the move will occur even if an obstacle
is in the way. Returns non-nil if a move occurred."
  (let ((world *world*))
    (multiple-value-bind (r c) 
	(step-in-direction ^row ^column direction distance)
      (cond ((null (grid-location world r c)) ;; are we at the edge?
	     ;; return nil because we didn't move
	     (prog1 nil
	     ;; edge conditions only affect player for now
	       (when (is-player self)
		 (ecase (field-value :edge-condition world)
		   (:block nil)
		   (:wrap nil) ;; TODO implement this for planet maps
		   (:exit (exit *universe*))))))
	    (t
	     (when (or ignore-obstacles 
		       (not (obstacle-at-p *world* r c)))
	       ;; return t because we moved
	       (prog1 t
		 (move-cell world self r c))))))))

(define-method on-collide cell (object)
  "Respond to a collision detected with OBJECT."
  nil)

;;; Sprites

(define-prototype sprite (:parent =cell=
				  :documentation 
"Sprites are IOFORMS game objects derived from cells. Although most
behaviors are compatible, sprites can take any pixel location in the
world, and collision detection is performed between sprites and cells.")
  (type :initform :sprite)
  (saved-x :initform nil :documentation "Saved x-coordinate used to jump back from a collision.")
  (saved-y :initform nil :documentation "Saved y-coordinate used to jump back from a collision.")
  (saved-z :initform nil :documentation "Saved z-coordinate used to jump back from a collision.")
  (height :initform nil :documentation "The cached width of the bounding box.")
  (width :initform nil :documentation "The cached height of the bounding box."))

;; Convenience macro for defining sprites

(defmacro defsprite (name &body args)
  `(define-prototype ,name (:parent =sprite=)
     ,@args))

(defun is-sprite (ob)
  (when (eq :sprite (field-value :type ob))))

(defun is-cell (ob)
  (when (eq :cell (field-value :type ob))))

(define-method update-image-dimensions sprite ()
  (with-fields (image height width) self
    (when image
      (setf width (image-width image))
      (setf height (image-height image)))))

(define-method initialize sprite ()
  (update-image-dimensions self))

(define-method die sprite ()
  (remove-sprite *world* self))

;;; Sprite locations

(define-method grid-coordinates sprite ()
  (values (truncate (/ ^y (field-value :tile-size *world*)))
	  (truncate (/ ^x (field-value :tile-size *world*)))))

(define-method xy-coordinates sprite ()
  (values ^x ^y))

(define-method coordinates sprite ()
  (values ^x ^y ^z))

;;; Sprite movement

(define-method move-to sprite (x y &optional z)
  (assert (and (integerp x) (integerp y)))
  (setf ^x x ^y y)
  (when (numberp z)
    (setf ^z z)))

(define-method move-to-grid sprite (row column)
  (with-field-values (grid-size) *world*
    (move-to self (* grid-size row) (* grid-size column))))

(define-method move sprite (direction &optional (distance 1))
  (assert (member direction *compass-directions*))
  (with-field-values (x y) self
    (multiple-value-bind (y0 x0) 
	(ioforms:step-in-direction y x direction distance)
      (assert (and y0 x0))
      (move-to self x0 y0))))

;;; Collision detection

(define-method collide sprite (sprite)
  (let ((x0 (field-value :x sprite))
	(y0 (field-value :y sprite))
	(w (field-value :width sprite))
	(h (field-value :height sprite)))
    (collide-* self y0 x0 w h)))
    
(define-method would-collide sprite (x0 y0)
  (with-field-values (tile-size grid sprite-grid) *world*
    (with-field-values (width height x y) self
      ;; determine squares sprite would intersect
      (let ((left (1- (floor (/ x0 tile-size))))
	    (right (1+ (floor (/ (+ x0 width) tile-size))))
	    (top (1- (floor (/ y0 tile-size))))
	    (bottom (1+ (floor (/ (+ y0 height) tile-size)))))
	;; search intersected squares for any obstacle
	(or (block colliding
	      (let (found)
		(dotimes (i (max 0 (- bottom top)))
		  (dotimes (j (max 0 (- right left)))
		    (let ((i0 (+ i top))
			  (j0 (+ j left)))
		      (when (array-in-bounds-p grid i0 j0)
			(when (collide-* self
					 (* i0 tile-size) 
					 (* j0 tile-size)
					 tile-size tile-size)
			  ;; save this intersection information
			  (vector-push-extend self (aref sprite-grid i0 j0))
			  ;; quit when obstacle found
			  (let ((obstacle (obstacle-at-p *world* i0 j0)))
			    (when obstacle
			      (setf found obstacle))))))))
		(return-from colliding found)))
	    ;; scan for sprite intersections
	    (block intersecting 
	      (let (collision num-sprites ix)
		(dotimes (i (max 0 (- bottom top)))
		  (dotimes (j (max 0 (- right left)))
		    (let ((i0 (+ i top))
			  (j0 (+ j left)))
		      (when (array-in-bounds-p grid i0 j0)
			(setf collision (aref sprite-grid i0 j0))
			(setf num-sprites (length collision))
			(when (< 1 num-sprites)
			  (dotimes (i (- num-sprites 1))
			    (setf ix (1+ i))
			    (loop do (let ((a (aref collision i))
					   (b (aref collision ix)))
				       (incf ix)
				       (assert (and (object-p a) (object-p b)))
				       (when (not (eq a b))
					 (let ((bt (field-value :y b))
					       (bl (field-value :x b))
					       (bh (field-value :height b))
					       (bw (field-value :width b)))
					   (when (collide y0 x0 width height bt bl bw bh)
					     (return-from intersecting t)))))
				  while (< ix num-sprites)))))))))
	      nil))))))
	    
(defun check-point-against-rectangle (x y width height o-top o-left o-width o-height)
  (let ((o-right (+ o-left o-width))
	(o-bottom (+ o-top o-height)))
    (not (or 
	  ;; is the top below the other bottom?
	  (< o-bottom y)
	  ;; is bottom above other top?
	  (< (+ y height) o-top)
	  ;; is right to left of other left?
	  (< (+ x width) o-left)
	  ;; is left to right of other right?
	  (< o-right x)))))

(define-method collide-* sprite (o-top o-left o-width o-height)
  (with-field-values (x y width height) self
    (check-point-against-rectangle x y width height o-top o-left o-width o-height)))

(define-method on-collide sprite (object)
  "Respond to a collision detected with OBJECT."
  (declare (ignore object))
  nil)

(define-method save-excursion sprite ()
  (setf ^saved-x ^x)
  (setf ^saved-y ^y)
  (setf ^saved-z ^z))

(define-method undo-excursion sprite ()
  (move-to self ^saved-x ^saved-y ^saved-z))

;;; Object dropping

(define-method drop sprite (cell &optional (delta-row 0) (delta-column 0))
  (multiple-value-bind (r c)
      (grid-coordinates self)
    (drop-cell *world* cell (+ r delta-row) (+ c delta-column))))

;;; Playing a sound

(define-method play-sound cell (sample-name)
  (play-sample sample-name))

;;; cells.lisp ends here
