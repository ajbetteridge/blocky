;; worlds.lisp --- places where gameplay happens

;; Copyright (C) 2006, 2007, 2008, 2009, 2010, 2011  David O'Toole

;; Author: David O'Toole %dto@ioforms.org
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
;; along with this program.  If not, see %http://www.gnu.org/licenses/

(in-package :blocky)

(define-block world
  (shell-mode :initform nil)
  (variables :initform nil 
	     :documentation "Hash table mapping values to values, local to the current world.")
  (player :documentation "The player object, if any.")
  (background-image :initform nil)
  (background-color :initform "white")
  (x :initform 0)
  (y :initform 0)
  (heading :initform 0.0)
  (height :initform 16)
  (width :initform 16)
  ;; objects and collisions
  (objects :initform nil :documentation "A hash table with all the world's objects.")
  (quadtree :initform nil)
  (quadtree-depth :initform nil)
  ;; viewing window
  (window-x :initform 0)
  (window-y :initform 0)
  (window-x0 :initform nil)
  (window-y0 :initform nil)
  (window-scrolling-speed :initform 2)
  (window-scale-x :initform 1)
  (window-scale-y :initform 1)
  ;; selection and region
  (selection :initform ()
  	     :documentation "List (subset) of selected blocks.")
  ;; the optional world shell ui 
  (system-menu :initform nil
	   :documentation "Optional system-menu widget. See system.lisp")
  (command-line :initform nil)
  (command-p :initform nil)
  (default-events :initform
		  '(((:tab) :tab)
		    ((:tab :control) :backtab)
		    ((:x :alt) :enter-command-line)
		    ((:g :control) :escape)
		    ((:s :alt) :toggle-shell)
		    ((:escape) :escape)))
  (excluded-fields :initform
		   '(:quadtree :click-start :click-start-block :drag-origin :drag-start :drag-offset :focused-block :command-line :system-menu :listener :drag :hover :highlight)
		   :documentation "Don't serialize the menu bar.")
  (drag :initform nil 
  	:documentation "Block being dragged, if any.")
  (hover :initform nil
	 :documentation "Block being hovered over, if any.")
  (highlight :initform nil
	     :documentation "Block being highlighted, if any.")
  (ghost :initform (new block)
	 :documentation "Dummy block to hold original place of currently dragged block onscreen.")
  (focused-block :initform nil
		 :documentation "Block having current input focus, if any.")
  (last-focus :initform nil)
  (click-start :initform nil
	      :documentation "A cons (X . Y) of widget location at moment of click.")
  (click-start-block :initform nil
		     :documentation "The block indicated at the beginning of a drag.")
  (drag-origin :initform nil
	       :documentation "The parent block originally holding the dragged block.")
  (drag-start :initform nil
	      :documentation "A cons (X . Y) of widget location at start of dragging.")
  (drag-offset :initform nil
	       :documentation "A cons (X . Y) of relative mouse click location on dragged block.")
  (modified :initform nil 
	  :documentation "Non-nil when modified since last save."))

(define-method show-shell world ()
  (setf %shell-mode t))

(define-method hide-shell world ()
  (setf %shell-mode nil))

(define-method toggle-shell world ()
  (if %shell-mode
      (hide-shell self)
      (show-shell self)))

(defmacro define-world (name &body body)
  `(define-block (,name :super "BLOCKY:WORLD")
     ,@body))

(define-method get-objects world ()
  (loop for object being the hash-keys in %objects collect object))

;; Defining and scrolling the screen viewing window

(define-method window-bounding-box world ()
  (values %window-y 
	  %window-x
	  (+ %window-x *gl-screen-width*)
	  (+ %window-y *gl-screen-height*)))

(define-method move-window-to world (x y)
  (setf %window-x x 
	%window-y y))

(define-method move-window world (dx dy)
  (incf %window-x dx)
  (incf %window-y dy))

(define-method glide-window-to world (x y)
  (setf %window-x0 x)
  (setf %window-y0 y))

(define-method glide-window-to-object world (object)
  (multiple-value-bind (top left right bottom) 
      (bounding-box object)
    (declare (ignore right bottom))
    (glide-window-to 
     self 
     (max 0 (- left (/ *gl-screen-width* 2)))
     (max 0 (- top (/ *gl-screen-width* 2))))))

(define-method glide-follow world (object)
  (with-fields (window-x window-y width height) self
    (let ((margin-x (* 1/3 *gl-screen-width*))
	  (margin-y (* 1/3 *gl-screen-height*))
	  (object-x (field-value :x object))
	  (object-y (field-value :y object)))
    ;; are we outside the "comfort zone"?
    (if (or 
	 ;; too far left
	 (> (+ window-x margin-x) 
	    object-x)
	 ;; too far right
	 (> object-x
	    (- (+ window-x *gl-screen-width*)
	       margin-x))
	 ;; too far up
	 (> (+ window-y margin-y) 
	    object-y)
	 ;; too far down 
	 (> object-y 
	    (- (+ window-y *gl-screen-height*)
	       margin-y)))
	;; yes. recenter.
	(glide-window-to self
			 (max 0
			      (min (- width *gl-screen-width*)
				   (- object-x 
				      (truncate (/ *gl-screen-width* 2)))))
			 (max 0 
			      (min (- height *gl-screen-height*)
				   (- object-y 
				      (truncate (/ *gl-screen-height* 2))))))))))

(define-method update-window-glide world ()
  (with-fields (window-x window-x0 window-y window-y0 window-scrolling-speed) self
    (labels ((nearby (a b)
	       (> window-scrolling-speed (abs (- a b))))
	     (jump (a b)
	       (if (< a b) window-scrolling-speed (- window-scrolling-speed))))
      (when (and window-x0 window-y0)
	(if (nearby window-x window-x0)
	    (setf window-x0 nil)
	    (incf window-x (jump window-x window-x0)))
	(if (nearby window-y window-y0)
	    (setf window-y0 nil)
	    (incf window-y (jump window-y window-y0)))))))

(define-method scale-window world (&optional (window-scale-x 1.0) (window-scale-y 1.0))
  (setf %window-scale-x window-scale-x)
  (setf %window-scale-y window-scale-y))

(define-method project-window world ()
  (do-orthographic-projection)
  (do-window %window-x %window-y %window-scale-x %window-scale-y))

(define-method is-empty world ()
  (or (null %objects)
      (zerop (hash-table-count %objects))))

(define-method initialize world ()
  (setf %variables (make-hash-table :test 'equal))
  (setf %objects (make-hash-table :test 'equal)))
  
(define-method handle-event world (event)
  (or (handle-event%%block self event)
      (with-fields (player quadtree) self
	(when player 
	  (prog1 t
	    (let ((*quadtree* quadtree))
	      (handle-event player event)))))))

;;; The object layer. 

(define-method add-block world (object &optional x y append)
  (with-fields (quadtree) self
    (let ((*quadtree* quadtree))
      (assert (not (gethash (find-uuid object) 
			    %objects)))
      (setf (gethash (find-uuid object)
		     %objects)
	    t)
      (when (and (numberp x) (numberp y))
	(setf (field-value :x object) x
	      (field-value :y object) y))
      (clear-saved-location object)
      (when quadtree
	(quadtree-insert quadtree object)))))

(define-method drop-block world (block x y)
  (add-block self block)
  (move-to block x y))
      
(define-method remove-block world (object)
  (remhash (find-uuid object) %objects)
  (when (field-value :quadtree-node object)
    (quadtree-delete %quadtree object)))

(define-method discard-block world (object)
  (remhash (find-uuid object) %objects))

;;; World-local variables

(define-method setvar world (var value)
  (setf (gethash var %variables) value))

(define-method getvar world (var)
  (gethash var %variables))

(defun world-variable (var-name)
  (getvar *world* var-name))

(defun set-world-variable (var-name value)
  (setvar *world* var-name value))

(defsetf world-variable set-world-variable)

(defmacro with-world-variables (vars &rest body)
  (labels ((make-clause (sym)
	     `(,sym (world-variable ,(make-keyword sym)))))
    (let* ((symbols (mapcar #'make-non-keyword vars))
	   (clauses (mapcar #'make-clause symbols)))
      `(symbol-macrolet ,clauses ,@body))))

;;; About the player
			        
(define-method get-player world ()
  %player)

(defun player ()
  (get-player *world*))

(define-method set-player world (player)
  (setf %player player)
  (add-block self player))

;;; Configuring the world's space and its quadtree indexing

(defparameter *world-bounding-box-scale* 1.01
  "Actual size of bounding box used for quadtree. The world is bordered
around on all sides by a thin margin designed to prevent objects near
the edge of the universe piling up into the top quadrant and causing
slowdown. See also quadtree.lisp")

(define-method install-quadtree world ()
  (unless (is-empty self)
    ;; make a box with a one-percent margin on all sides.
    ;; this margin helps edge objects not pile up in quadrants
    (let ((box (multiple-value-list
		(scale-bounding-box 
		 (multiple-value-list (bounding-box self))
		 *world-bounding-box-scale*))))
      (destructuring-bind (top left right bottom) box
	(with-fields (quadtree) self
	  (setf quadtree (build-quadtree 
			  box 
			  (or %quadtree-depth 
			      *default-quadtree-depth*)))
	  (quadtree-fill quadtree (get-objects self)))))))

(define-method resize world (new-height new-width)
  (assert (and (plusp new-height)
	       (plusp new-width)))
  (with-fields (height width quadtree objects) self
    (setf height new-height)
    (setf width new-width)
    (when quadtree
      (install-quadtree self))))

(define-method shrink-wrap world ()
  (prog1 self
    (let ((objects (get-objects self)))
      (with-fields (quadtree height width) self
	;; adjust bounding box so that all objects have positive coordinates
	(multiple-value-bind (top left right bottom)
	    (find-bounding-box objects)
	  ;; move all the objects
	  (dolist (object objects)
	    (with-fields (x y) object
	      (move-to object (- x left) (- y top))))
	  ;; resize the world so that everything just fits
	  (setf %x 0 %y 0)
	  (resize self (- bottom top) (- right left)))))))

;; Algebraic operations on worlds and their contents

(defvar *world-prototype* "BLOCKY:WORLD")

(defmacro with-world (world &rest body)
  `(let ((*world* ,world))
     (prog1 *world*
       ,@body)))

(defmacro with-world-prototype (world &rest body)
  `(let ((*world-prototype* (find-super ,world)))
     ,@body))

(define-method adjust-bounding-box-maybe world ()
  (if (is-empty self)
      self
      (let ((objects-bounding-box 
	      (multiple-value-list 
	       (find-bounding-box (get-objects self)))))
	(destructuring-bind (top left right bottom)
	    objects-bounding-box
	  ;; are all the objects inside the existing box?
	  (prog1 self
	    (unless (bounding-box-contains 
		     (multiple-value-list (bounding-box self))
		     objects-bounding-box)
	      (resize self bottom right)))))))

(defmacro with-new-world (&body body)
  `(with-world (clone *world-prototype*) 
     ,@body
     (adjust-bounding-box-maybe (world))))

(define-method paste world (other-world &optional (dx 0) (dy 0))
  (dolist (object (get-objects other-world))
    (with-fields (x y) object
      (clear-saved-location object)
      (add-block self object)
      (move-to object (+ x dx) (+ y dy)))))

(defun translate (world dx dy)
  (when world
    (assert (and (numberp dx) (numberp dy)))
    (with-new-world 
      (paste (world) world dx dy))))

(defun combine (world1 world2)
  (with-new-world 
    (when (and world1 world2)
      (dolist (object (nconc (get-objects world1)
			     (mapcar #'duplicate (get-objects world2))))
	(add-block (world) object)))))

(define-method scale world (sx &optional sy)
  (let ((objects (get-objects self)))
    (dolist (object objects)
      (with-fields (x y width height) object
	(move-to object (* x sx) (* y (or sy sx)))
	(resize object (* width sx) (* height (or sy sx))))))
  (shrink-wrap self))

(define-method destroy-region world (bounding-box))

(define-method copy world ()
  (with-new-world 
    (dolist (object (mapcar #'duplicate (get-objects self)))
      (add-block (world) object))))

(defun vertical-extent (world)
  (if (or (null world)
	  (is-empty world))
      0
      (multiple-value-bind (top left right bottom)
	  (bounding-box world)
	(declare (ignore left right))
	(- bottom top))))

(defun horizontal-extent (world)
  (if (or (null world)
	  (is-empty world))
      0
      (multiple-value-bind (top left right bottom)
	  (bounding-box world)
	(declare (ignore top bottom))
	(- right left))))
  
(defun arrange-below (&optional world1 world2)
  (when (and world1 world2)
    (combine world1
	     (translate world2
			0 
			(field-value :height world1)))))

(defun arrange-beside (&optional world1 world2)
  (when (and world1 world2)
    (combine world1 
	     (translate world2
			(field-value :width world1)
			0))))

(defun stack-vertically (&rest worlds)
  (reduce #'arrange-below worlds :initial-value (with-new-world)))

(defun stack-horizontally (&rest worlds)
  (reduce #'arrange-beside worlds :initial-value (with-new-world)))

(define-method flip-horizontally world ()
  (let ((objects (get-objects self)))
    (dolist (object objects)
      (with-fields (x y) object
	(move-to object (- x) y))))
  ;; get rid of negative coordinates
  (shrink-wrap self))

(define-method flip-vertically world ()
  (let ((objects (get-objects self)))
    (dolist (object objects)
      (with-fields (x y) object
	(move-to object x (- y)))))
  (shrink-wrap self))

(define-method mirror-horizontally world ()
  (stack-horizontally 
   self 
   (flip-horizontally (duplicate self))))

(define-method mirror-vertically world ()
  (stack-vertically 
   self 
   (flip-vertically (duplicate self))))

(defun with-border (border world)
  (with-fields (height width) world
    (with-new-world 
      (paste (world) world border border) 
      (resize (world)
	      (+ height (* border 2))
	      (+ width (* border 2))))))

;;; The Shell is an optional layer of objects on top of the world

;; Including a system menu, editor, and controls for switching worlds
;; and pages in the system. Maybe zooming out on a mega virtual desktop.

(define-method grab-focus world ())

(define-method layout-shell-objects world ()
  (mapc #'layout %inputs))

(define-method update-shell-objects world ()
  (mapc #'update %inputs)
  (when %command-line (update %command-line))
  (when %system-menu (update %system-menu)))

(define-method draw-shell-objects world ()
  (with-world self
    (with-fields (drag-start selection inputs drag
			 focused-block highlight system-menu
			 command-line command-p inputs
			 modified hover ghost prompt)
	self
      ;; now start drawing the shell objects
      (mapc #'draw inputs)
	;; draw border around any selected blocks
	;; (when (find block selection :test 'eq :key #'find-object)
	;;   (draw-border block))
      ;; possibly draw command line background
      (when command-p
	(draw command-line))
      ;; during dragging we draw the dragged block.
      (if drag 
	    (progn (layout drag)
		   (when (field-value :parent drag)
		     (draw-ghost ghost))
		   ;; also draw any hover-over highlights 
		   ;; on objects you might drop stuff onto
		   (when hover 
		     (draw-hover hover))
		   (draw drag))
	    (when focused-block
	      (assert (blockyp focused-block))
	      (draw-focus focused-block)))
	(when system-menu
	  (with-style :rounded
	    (draw system-menu)))
	(when highlight
	  (draw-highlight highlight)))))

(define-method draw world ()
  (with-world self
    (project-window self)
    (with-field-values (objects quadtree width height background-image background-color) self
      ;; draw background 
      (if background-image
	  (draw-image background-image 0 0)
	  (when background-color
	    (draw-box 0 0 width height
		      :color background-color)))
      (let ((box (multiple-value-list (window-bounding-box self))))
	(loop for object being the hash-keys in objects do
	  ;; only draw onscreen objects
	  (when (colliding-with-bounding-box object box)
	    (draw object))))
      ;; possibly draw shell
      (when %shell-mode 
	(draw-shell-objects self)))))
  
;;; Simulation update

(define-method update world (&optional no-collisions)
  (let ((*world* self))
    (layout self)
    (with-field-values (quadtree objects height width player) self
      ;; build quadtree if needed
      (when (null quadtree)
      	(install-quadtree self))
      (let ((*quadtree* %quadtree))
	(assert (zerop *quadtree-depth*))
	;; run the objects
	(loop for object being the hash-keys in %objects do
	  (update object)
	  (run-tasks object))
	;; update window movement
	(when player 
	  (glide-follow self player)
	  (update-window-glide self))
	;; detect collisions
	(unless no-collisions
	  (loop for object being the hash-keys in objects do
	    (unless (eq :passive (field-value :collision-type object))
	      (quadtree-collide *quadtree* object)))))
      ;; possibly update the shell
      (when %shell-mode
	(layout-shell-objects self)
	(update-shell-objects self)))))

;;; A trash can for user-discarded objects

(defvar *trash* nil)

(define-block trash 
  :category :system 
  :methods '(:empty))

(define-method evaluate trash ())

(define-method update trash ())

(define-method empty trash ()
  (setf *trash* nil))

(define-method accept trash (item)
  (push item *trash*))

(defun-memo trash-status-string (count)
    (:key #'first :test 'equal :validator #'identity)
  (format nil "trash (~S items)" count))

(define-method layout trash ()
  (setf %width (dash 4 (font-text-extents 
		       (trash-status-string 
			(length %inputs))
		       *font*)))
  (setf %height (dash 4 (font-height *font*))))

(define-method draw trash ()
  (draw-background self)
  (draw-label-string self (trash-status-string (length *trash*))
		     "yellow"))

(define-method draw-hover trash ())

(defun make-command-line ()
  (find-uuid (new command-line)))

(define-method enter-command-line world ()
  (setf %command-p t)
  (setf %last-focus %focused-block)
  (focus-on self %command-line))

(define-method exit-command-line world ()
  (setf %command-p nil)
  (focus-on self %last-focus)
  (setf %last-focus nil))

(define-method make-widgets world ()
  (setf *world* (find-uuid self))
  (setf %command-line (make-command-line)))

(define-method add-system-menu world ()
  (setf %system-menu (make-system-menu)))

(define-method after-deserialize world ()
  (clear-drag-data self)
  (make-widgets self))

(defmacro with-world (world &rest body)
  (let ((sh (gensym)))
    `(let* ((,sh ,world)
	    (*world* ,sh))
       ,@body)))

(define-method layout world ()
  ;; take over the entire GL window
  (with-world self
    (setf %x 0 %y 0 
	  %width *screen-width* 
	  %height *screen-height*)
    ;; run system-menu across top
    (when %system-menu
      (with-style :rounded
	(layout %system-menu)))
    ;; run command line across bottom
    (when %command-line 
      (layout %command-line))
    ;;
    (mapc #'layout %inputs)))

(define-method select world (block &optional only)
  (with-world self
    (with-fields (selection) self
      (if only
	  (setf selection (list block))
	  (progn 
	    (pushnew block selection 
		     :test 'eq :key #'find-parent)
	    (select block))))))
  
(define-method select-if world (predicate)
  (with-world self
    (with-fields (selection inputs) self
      (setf selection 
	    (remove-if predicate inputs
		       :key #'find-parent)))))
  
(define-method unselect world (block)
  (with-world self
    (with-fields (selection) self
      (setf selection (delete block selection 
			      :test 'eq :key #'find-parent)))))
  
(define-method handle-event world (event)
  (with-world self
    (or (super%handle-event self event)
	(with-field-values (focused-block selection command-line inputs) self
	  (let ((block
		    (cond
		      ;; we're focused. send the event there
		      (focused-block
		       (prog1 focused-block
			 (assert (blockyp focused-block))))
		      ;; only one block selected. use that.
		      ((= 1 (length selection))
		       (first selection))
		      ;; fall back to command-line
		      (t command-line))))
	    (when block 
	      (handle-event block event)))))))

;;; Hit testing

(define-method hit world (x y)
  ;; return self no matter where mouse is, so that we get to process
  ;; all the events.
  (declare (ignore x y))
  self)

(define-method hit-inputs world (x y)
  "Recursively search the blocks in this world for a block
intersecting the point X,Y. We have to search the top-level blocks
starting at the end of `%INPUTS' and going backward, because the
blocks are drawn in list order (i.e. the topmost blocks for
mousing-over are at the end of the list.) The return value is the
block found, or nil if none is found."
  (with-world self 
    (labels ((try (b)
	       (when b
		 (hit b x y))))
      ;; check system-menu, then buffer
      (or 
       (when %command-p 
	 (try %command-line))
       (when %system-menu (try %system-menu))
       (let ((parent 
	       (find-if #'try 
			%inputs
			:from-end t)))
	 (when parent
	   (try parent)))))))
  
(defparameter *minimum-drag-distance* 7)
  
(define-method focus-on world (block)
  ;; possible to pass nil
  (with-fields (focused-block) self
    (with-world self
      (let ((last-focus focused-block))
	;; there's going to be a new focused block. 
	;; tell the current one it's no longer focused.
	(when (and last-focus
		   ;; don't do this for same block
		   (not (object-eq last-focus block)))
	  (discard-halo last-focus)
	  (lose-focus last-focus))
      ;; now set up the new focus (possibly nil)
      (setf focused-block (when block (find-uuid block)))
      ;; sanity check
      (assert (or (null focused-block)
		  (blockyp focused-block)))
      ;; now tell the block it has focus, but only if not the same
      (when (and focused-block
		 (not (object-eq last-focus focused-block)))
	(focus block))))))

(define-method begin-drag world (mouse-x mouse-y block)
  (with-fields (drag drag-origin inputs drag-start ghost drag-offset) self
    (with-world self
      (setf drag (pick-drag block mouse-x mouse-y))
      (setf drag-origin (find-parent drag))
      (when drag-origin
	  ;; parent might produce a new object
	(unplug-from-parent block))
      (let ((dx (field-value :x block))
	    (dy (field-value :y block))
	    (dw (field-value :width block))
	    (dh (field-value :height block)))
	(with-fields (x y width height) ghost
	  ;; remember the relative mouse coordinates from the time the
	  ;; user began dragging, so that the block being dragged is not
	  ;; simply anchored with its top left corner located exactly at
	  ;; the mouse pointer.
	  (let ((x-offset (- mouse-x dx))
		(y-offset (- mouse-y dy)))
	    (when (null drag-start)
	      (setf x dx y dy width dw height dh)
	      (setf drag-start (cons dx dy))
	      (setf drag-offset (cons x-offset y-offset)))))))))

(define-method drag-maybe world (x y)
  ;; require some actual mouse movement to initiate a drag
  (with-world self
    (with-fields (focused-block click-start click-start-block) self
      (when click-start
	(destructuring-bind (x1 . y1) click-start
	  (when (and focused-block click-start-block
		     (> (distance x y x1 y1)
			*minimum-drag-distance*)
		     (can-pick click-start-block))
	    (let ((drag (pick click-start-block)))
	      (begin-drag self x y drag)
	      ;; clear click data
	      (setf click-start nil)
	      (setf click-start-block nil))))))))

(define-method handle-point-motion world (mouse-x mouse-y)
  (with-fields (inputs hover highlight click-start drag-offset
		       drag-start drag) self
    (setf hover nil)
    (drag-maybe self mouse-x mouse-y)
    (if drag
	;; we're in a mouse drag.
	(destructuring-bind (ox . oy) drag-offset
	  (let ((target-x (- mouse-x ox))
		(target-y (- mouse-y oy)))
	    (let ((candidate (hit-inputs self target-x target-y)))
	      ;; obviously we dont want to plug a block into itself.
	      (setf hover (if (object-eq drag candidate) nil
			      (find-uuid candidate)))
	      ;; keep moving along with the mouse
	      (drag drag target-x target-y))))
	;; not dragging, just moving
	(progn
	  (setf highlight (find-uuid (hit-inputs self mouse-x mouse-y)))
	  (when (null highlight)
	    (when %system-menu
	      (with-world self (close-menus %system-menu))))))))

(define-method press world (x y &optional button)
  (declare (ignore button))
  (with-fields (click-start click-start-block focused-block) self
    ;; now find what we're touching
    (assert (or (null focused-block)
		(blockyp focused-block)))
    (let ((block (hit-inputs self x y)))
      (if (null block)
	  (progn
	    (focus-on self nil)
	    (when %command-p
	      (exit-command-line self)))
	  (progn 
	    (setf click-start (cons x y))
	    (setf click-start-block (find-uuid block))
	    ;; now focus; this might cause another block to be
	    ;; focused, as in the case of the Listener
	    (focus-on self block))))))

(define-method clear-drag-data world ()
  (setf %drag-start nil
	%drag-offset nil
	%drag-origin nil
	%drag nil))
	;; %click-start-block nil
	;; %click-start nil))
  
(define-method release world (x y &optional button)
  (with-world self
    (with-fields 
	(drag-offset drag-start hover selection drag click-start
		     click-start-block drag-origin focused-block modified) self
      (if drag
	  ;; we're dragging
	  (destructuring-bind (x0 . y0) drag-offset
	    (let ((drag-parent (get-parent drag))
		  (drop-x (- x x0))
		  (drop-y (- y y0)))
	      (if (not (can-escape drag))
		  ;; put back in halo or wherever
		  (when drag-origin 
		    (add-block drag-origin drag drop-x drop-y))
		  ;; ok, drop. where are we dropping?
		  (progn 
		    (when drag-parent
		      (unplug-from-parent drag))
		    (if (null hover)
			;; dropping on background
			(add-block self drag drop-x drop-y)
			;; dropping on another block
			(when (not (accept hover drag))
			  ;; hovered block did not accept drag. 
			  ;; drop it back in the world.
			  (add-block self drag drop-x drop-y)))))
	      ;; select the dropped block
	      (progn 
		(select self drag)
		(setf focused-block (find-uuid drag)))))
	  ;;
	  ;; we were clicking instead of dragging
	  (progn
	    (setf selection nil)
	    (when focused-block
	      (select self focused-block)
	      (with-world self 
		(if 
		 ;; right click and control click are interpreted the same
		 (or (holding-control)
		     (= button 3))
		 (alternate-tap focused-block x y)
		 (tap focused-block x y))
		(select self focused-block))
	      (setf click-start nil))))
      (clear-drag-data self)
      (invalidate-layout self))))

(define-method tab world (&optional backward)
  (with-fields (focused-block) self
    (when focused-block
      (assert (blockyp %focused-block))
      (with-fields (parent) focused-block
	(let ((index (position-within-parent focused-block)))
	  (when (numberp index)
	    (focus-on self
		      (with-fields (inputs) parent
			(nth (mod (+ index
				     (if backward -1 1))
				  (length inputs))
			     inputs)))))))))

(define-method backtab world ()
  (tab self :backward))
  
(define-method escape world ()
  (with-world self
    (when %system-menu (close-menus %system-menu))
    (focus-on self nil)
    (exit-command-line self)
    (setf %selection nil)))


;;; worlds.lisp ends here
