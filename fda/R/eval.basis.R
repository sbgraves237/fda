predict.basisfd <- function(object, newdata=NULL, Lfdobj=0, ...){
##
## 1.  newdata?
##
  if(is.null(newdata)){
    type <- object$type
    if(length(type) != 1)
      stop('length(object$type) must be 1;  is ',
           length(type) )
    newdata <- {
      if(type=='bspline') {
        unique(knots(object, interior=FALSE))
      } else object$rangeval
    }
  }
##
## 2.  eval.basis
##
  eval.basis(newdata, object, Lfdobj)
}

eval.basis <- function(evalarg, basisobj, Lfdobj=0) {
#  Computes the basis matrix evaluated at arguments in EVALARG associated
#    with basis.fd object BASISOBJ.  The basis matrix contains the values
#    at argument value vector EVALARG of applying the nonhomogeneous
#    linear differential operator LFD to the basis functions.  By default
#    LFD is 0, and the basis functions are simply evaluated at argument
#    values in EVALARG.
#
#  If LFD is a functional data object with m + 1 functions c_1, ... c_{m+1},
#   then it is assumed to define the order m HOMOGENEOUS linear differential
#   operator
#
#            Lx(t) = c_1(t) + c_2(t)x(t) + c_3(t)Dx(t) + ... +
#                    c_{m+1}D^{m-1}x(t) + D^m x(t).
#
#  If the basis type is either polygonal or constant, LFD is ignored.
#
#  Arguments:
#  EVALARG ... Either a vector of values at which all functions are evaluated,
#              or a matrix of values, with number of columns corresponding to
#              number of functions in argument FD.  If the number of evaluation
#              values varies from curve to curve, pad out unwanted positions in
#              each column with NA.  The number of rows is equal to the maximum
#              of number of evaluation points.
#  BASISOBJ ... A basis object
#  LFDOBJ   ... A linear differential operator object
#               applied to the basis functions before they are to be evaluated.

#  Note that the first two arguments may be interchanged.

#  Last modified 6 January 2020
##
## 1.  check
##
#   Exchange the first two arguments if the first is a BASIS.FD object
#     and the second numeric

  if (is.numeric(basisobj) && inherits(evalarg, "basisfd")) {
    temp     <- basisobj
    basisobj <- evalarg
    evalarg  <- temp
  }

#  check EVALARG

#  if (!(is.numeric(evalarg))){# stop("Argument EVALARG is not numeric.")
# turn off warnings in checking if argvals can be converted to numeric.
  if(is.numeric(evalarg)){
    if(!is.vector(evalarg)) stop("Argument 'evalarg' is not a vector.")
    Evalarg <- evalarg
  } else {
    op <- options(warn=-1)
    Evalarg <- as.numeric(evalarg)
    options(op)
    nNA <- sum(is.na(Evalarg))
    if(nNA>0)
      stop('as.numeric(evalarg) contains ', nNA,
           ' NA', c('', 's')[1+(nNA>1)],
           ';  class(evalarg) = ', class(evalarg))
#  if(!is.vector(Evalarg))
#      stop("Argument EVALARG is not a vector.")
  }

#  check basisobj

  if (!(inherits(basisobj, "basisfd"))) stop(
    "Second argument is not a basis object.")

#  check LFDOBJ

  Lfdobj <- int2Lfd(Lfdobj)
##
## 2.  set up
##
#  determine the highest order of derivative NDERIV required

  nderiv <- Lfdobj$nderiv

#  get weight coefficient functions

  bwtlist <- Lfdobj$bwtlist
##
## 3.  Do
##
#  get highest order of basis matrix

  basismat <- getbasismatrix(evalarg, basisobj, nderiv)

#  Compute the weighted combination of derivatives is
#  evaluated here if the operator is not defined by an
#  integer and the order of derivative is positive.

  if (nderiv > 0) {
    nbasis    <- dim(basismat)[2]
    oneb      <- matrix(1,1,nbasis)
    nonintwrd <- FALSE
    for (j in 1:nderiv) {
        bfd    <- bwtlist[[j]]
        bbasis <- bfd$basis
        if (bbasis$type != "constant" || bfd$coefs != 0) nonintwrd <- TRUE
    }
    if (nonintwrd) {
      for (j in 1:nderiv) {
        bfd   <- bwtlist[[j]]
        if (!all(c(bfd$coefs) == 0.0)) {
            wjarray   <- eval.fd(evalarg, bfd, 0)
            Dbasismat <- getbasismatrix(evalarg, basisobj, j-1)
            basismat  <- basismat + (wjarray %*% oneb)*Dbasismat
        }
      }
    }
  }

  return(basismat)

}

