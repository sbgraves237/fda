smooth.basis <- function(argvals=1:n, y, fdParobj,
                         wtvec=NULL,   fdnames=NULL, covariates=NULL,
                         method="chol", dfscale=1) {
#  Arguments:
# ARGVALS  A set of N argument values, set by default to equally spaced
#             on the unit interval (0,1).
# Y        an array containing values of curves
#             If the array is a matrix, rows must correspond to argument
#             values and columns to replications, and it will be assumed
#             that there is only one variable per observation.
#             If Y is a three-dimensional array, the first dimension
#             corresponds to argument values, the second to replications,
#             and the third to variables within replications.
#             If Y is a vector, only one replicate and variable are assumed.
# FDPAROBJ A functional parameter or fdPar object.  This object
#             contains the specifications for the functional data
#             object to be estimated by smoothing the data.  See
#             comment lines in function fdPar for details.
#             This argument may also be either a FD object, or a
#             BASIS object.  In this case, the smoothing parameter
#             LAMBDA is set to 0.
# WEIGHT   A vector of N weights, set to one by default, that can
#             be used to differentially weight observations, or
#             a symmetric positive definite matrix of order N
# FDNAMES  A cell of length 3 with names for
#             1. argument domain, such as "Time"
#             2. replications or cases
#             3. the function.
# COVARIATES  A N by Q matrix Z of covariate values used to augment
#             the smoothing function, where N is the number of
#             data values to be smoothed and Q is the number of
#             covariates.  The process of augmenting a smoothing
#             function in this way is often called "semi-parametric
#             regression".  The default is the null object NULL.
# METHOD      The method for computing coefficients.  The usual method
#             computes cross-product matrices of the basis value matrix,
#             adds the roughness penalty, and uses the Choleski
#             decomposition of this to compute coefficients, analogous
#             to using the normal equations in least squares fitting.
#             But this approach, while fast, contributes unnecessary
#             rounding error, and the qr decomposition of the augmented
#             basis matrix is prefererable.  But nothing comes for free,
#             and the computational overhead of the qr approach can be a
#             serious problem for large problems (n of 1000 or more).
#             For this reason, the default is "method" = "chol", but if
#             'method' == 'qr', the qr decomposition is used.
# DFFACTOR A multiplier of df in GCV, set to one by default
#
# Returns a list containing:
#   FDOBJ   an object of class fd containing coefficients.
#   DF      a degrees of freedom measure.
#   GCV     a measure of lack of fit discounted for df.
#              If the function is univariate, GCV is a vector
#              containing the error  sum of squares for each
#              function, and if the function is multivariate,
#              GCV is a NVAR by NCURVES matrix.
#   COEF    the coefficient matrix for the basis function
#                expansion of the smoothing function
#   SSE     the error sums of squares.
#              SSE is a vector or matrix of the same size as
#              GCV.
#   PENMAT  the penalty matrix.
#   Y2CMAP  the matrix mapping the data to the coefficients.

#  This version of smooth.basis, introduced in March 2011, permits ARGVALS
#  to be a matrix, with the same dimensions as the first two dimensions of Y
#  This allows the sampling points to vary from one record to another.
#  This first section of code selects the version of smooth.basis to use
#  depending on whether ARGVALS is a vector (case 1) or a matrix (case 2)
#  The earlier version of smooth.basis is found at the end of the file where
#  it is named smooth.basis1.

#  Last modified 6 January 2020 by Jim Ramsay

#  check y

if (!is.numeric(y)) stop("'y' is not numeric.")
if (is.vector(y)) y <- as.matrix(y)
dimy <- dim(y)
ndy  <- length(dimy)
n    <- dimy[1]

#  check argvals

if (!is.numeric(argvals)) stop("'argvals' is not numeric.")
if (is.vector(argvals)) argvals <- as.matrix(argvals)
dima <- dim(argvals)
nda  <- length(dima)
if (ndy < nda) stop("argvals has ", nda, " dimensions  y has only ", ndy)

#  select which version of smooth.basis to use, according to dim. of argvals
#  are all dimensions of argvals equal to the first nda of those of y?

if (nda < 3 ) {
  if (dima[2] == 1) {

      sb2 <- smooth.basis1(argvals, y, fdParobj,
                           wtvec=wtvec,   fdnames=fdnames,
                           covariates=covariates,
                           method=method, dfscale=dfscale)

  } else {

      sb2 <- smooth.basis2(argvals, y=y, fdParobj=fdParobj,
                           wtvec=wtvec,   fdnames=fdnames,
                           covariates=covariates,
                           method=method, dfscale=dfscale)

  }
  return(sb2)
}

if (nda < 4) {
  return(smooth.basis3(argvals, y=y, fdParobj=fdParobj,
                       wtvec=wtvec,   fdnames=fdnames,
                       covariates=covariates,
                       method=method, dfscale=dfscale) )
} else {
      #  dimensions of argval inconsistent with those of y, throw error
      cat("dim(argvals) =", paste(dima, collapse=", "), "\n")
      cat("dim(y)      = ", paste(dimy, collapse=", "), "\n")
      stop("Dimensions of argvals do not match those of y")
      return()
}

}


################################################################################

smooth.basis3 <- function(argvals=array(1:n,c(n,N,M)), y, fdParobj,
                          wtvec=NULL,   fdnames=NULL, covariates=NULL,
                          method="chol", dfscale=1)
{
##
## 1.  check dimensions of argval and y
##

dimy <- dim(y)
ndy <- length(dimy)
n   <- dimy[1]
N   <- dimy[2]
M   <- dimy[3]
if (ndy < 3)stop("length(dim(y)) must be 3  is ", ndy)
if (any(dima != dimy)) {
    stop("dim(argvals) = ", paste(dima, collapse=", "),
         " != dim(y) = ", paste(dimy, collapse=", "))
}

dima <- dim(argvals)
nda  <- length(dima)
if (nda < 3) stop("length(dim(argvals)) must be 3  is ", nda)

##
## 2.  Call smooth.basis2 repeatedly
##
#  2.1.  argvals[, , 1]
sb1 <- smooth.basis2(argvals[, , 1], y=y[, , 1], fdParobj=fdParobj,
                     wtvec=wtvec,   fdnames=fdnames,
                     covariates=covariates,
                     method=method, dfscale=dfscale)
#  2.2.  set up output object
coef1 <- sb1$fd$coefs
dimc1 <- dim(coef1)
dimc  <- c(dimc1[1], dimy[-1])
coefs <- array(NA, dim=dimc)
argNames <- dimnames(argvals)
yNames   <- dimnames(y)
c1Names  <- dimnames(coef1)
cNames   <- vector("list", 3)
if (!is.null(c1Names[[1]])) cNames[[1]] <- c1Names[[1]]
if (!is.null(yNames[[2]]))  cNames[[2]] <- yNames[[2]]
if (!is.null(yNames[[3]]))  cNames[[3]] <- yNames[[3]]
dimnames(coefs) <- cNames
if (!is.null(covariates)) {
  q <- dim(covariates)[2]
  beta. <- array(0,c(q,dimy[2],dimy[3]))
  beta.[,,1] <- sb1$beta
} else {
  beta. <- NULL
}
#
for (i in seq(2, length=dimy[3]-1)) {
    sbi <- smooth.basis2(argvals[,,i], y=y[,,i], fdParobj=fdParobj,
                         wtvec=wtvec,   fdnames=fdnames,
                         covariates=covariates,
                         method=method, dfscale=dfscale)
    coefs[,,i] <- sbi$fd$coefs
    if (!is.null(covariates)) {
      beta.[,,i] <- sbi$beta
    }
}
if (is.null(fdnames)) {
    fdnames <- list(time=NULL, reps=NULL, values=NULL)
    if (!is.null(yNames[[1]])) {
        fdnames[[1]] <- yNames[[1]]
    } else {
      if (!is.null(argNames[[1]]))
        fdnames[[1]] <- argNames[[1]]
    }
    if (!is.null(yNames[[2]])) {
        fdnames[[2]] <- yNames[[2]]
    } else {
      if (!is.null(argNames[[2]]))
        fdnames[[2]] <- argNames[[2]]
    }
    if (!is.null(yNames[[3]])) {
        fdnames[[3]] <- yNames[[3]]
    } else {
      if (!is.null(argNames[[3]]))
        fdnames[[3]] <- argNames[[3]]
    }
}
##
## 3.  done
##
sb <- sb1
sb$fd$coefs   <- coefs
sb$fd$fdnames <- fdnames
sb$beta       <- beta.
sb

}

################################################################################

smooth.basis2 <- function(argvals=matrix(1:n,n,N), y, fdParobj,
                          wtvec=NULL,   fdnames=NULL, covariates=NULL,
                          method="chol", dfscale=1) {
##
## 1.  number of  dimensions of y = 2 or 3?
##
dimy     <- dim(y)
ndy      <- length(dimy)
n        <- dimy[1]
N        <- dimy[2]
ynames   <- dimnames(y)
argNames <- dimnames(argvals)
##
## 2.  ndy == 2
##
if (ndy < 3) {
    #  2.1.  Start by smoothing first record using argvals[, 1]

    sb1 <- smooth.basis1(argvals[, 1], y=y[, 1], fdParobj=fdParobj,
                         wtvec=wtvec,   fdnames=fdnames,
                         covariates=covariates,
                         method=method, dfscale=dfscale)

    #  2.2.  set up output object
    dimc1   <- dim(sb1$fd$coefs)
    dimc    <- c(dimc1[1], dimy[-1])
    coefs   <- array(NA, dim=dimc)
    c1names <- dimnames(sb1$fd$coefs)
    cNames  <- vector("list", 2)
    if (!is.null(c1names[[1]])) cNames[[1]] <- c1names[[1]]
    if (!is.null(ynames[[2]]))  cNames[[2]] <- ynames[[2]]
    dimnames(coefs) <- cNames
    coefs[, 1] <- sb1$fd$coefs
    if (!is.null(covariates)) {
      q <- dim(covariates)[2]
      beta. <- matrix(0,q,dimy[2])
      beta.[,1] <- sb1$beta
    } else {
      beta. <- NULL
    }
    #   now loop through remaining records, smoothing each in term,
    #   using argvals[,1]
    for (i in seq(2, length=dimy[2]-1)) {

      sbi <- smooth.basis1(argvals[, i], y=y[, i], fdParobj=fdParobj,
                           wtvec=wtvec,   fdnames=fdnames,
                           covariates=covariates,
                           method=method, dfscale=dfscale)

      coefs[, i] <- sbi$fd$coefs
      if (!is.null(covariates)) {
        beta.[,i] <- sbi$beta
      }
    }
    if (is.null(fdnames)) {
      fdnames <- sb1$fdnames
      if (is.null(fdnames))
        fdnames <- list(time=NULL, reps=NULL, values="value")
      valueChk <- ((length(fdnames$values)==1)
                   && (fdnames$values=="value")
                   && (length(fdnames$reps)==1)
                   && (!is.null(ynames[[2]])) )
      if (valueChk)fdnames$values <- fdnames$reps
      if (!is.null(ynames[[2]]))
        fdnames[[2]] <- ynames[[2]]
    }
} else{
##
## 3.  ndy == 3
##
    #  3.1.  argvals[, 1]
    sb1 <- smooth.basis1(argvals[, 1], y=y[, 1, ], fdParobj=fdParobj,
                         wtvec=wtvec,   fdnames=fdnames,
                         covariates=covariates,
                         method=method, dfscale=dfscale)
    #  3.2.  set up output object
    coef1 <- sb1$fd$coefs
    dimc1 <- dim(coef1)
    dimc <- c(dimc1[1], dimy[-1])
    coefs <- array(NA, dim=dimc)
    yNames <- dimnames(y)
    c1Names <- dimnames(coef1)
    cNames <- vector("list", 3)
    if (!is.null(c1Names[[1]]))  cNames[[1]] <- c1Names[[1]]
    if (!is.null(yNames[[2]]))   cNames[[2]] <- yNames[[2]]
    if (is.null(c1Names[[2]])) {
      if (!is.null(yNames[[3]])) cNames[[3]] <- yNames[[3]]
    } else {
      cNames[[3]] <- c1Names[[2]]
    }
    dimnames(coefs) <- cNames
    coefs[, 1, ] <- coef1
    if (!is.null(covariates)) {
      q <- dim(covariates)[2]
      beta. <- array(0,c(q,dimy[2],dimy[3]))
      beta.[,,1] <- sb1$beta
    } else {
      beta. <- NULL
    }
    #
    for (i in seq(2, length=dimy[2]-1)) {
      sbi <- smooth.basis1(argvals[, i], y=y[, i, ], fdParobj=fdParobj,
                           wtvec=wtvec,   fdnames=fdnames,
                           covariates=covariates,
                           method=method, dfscale=dfscale)
      coefs[, i, ] <- sbi$fd$coefs
      if (!is.null(covariates)) {
        beta.[,,i] <- sbi$beta
      } else {
        beta. <- NULL
      }
    }
    if (is.null(fdnames)) {
      fdnames <- sb1$fdnames
      if (is.null(fdnames)) {
        fdnames <- list(time=NULL, reps=NULL, values=NULL)
        if (!is.null(argNames[[1]])) {
          fdnames[[1]] <- argNames[[1]]
        } else {
          fdnames[[1]] <- ynames[[1]]
        }
        if (!is.null(ynames[[2]]))fdnames[[2]] <- ynames[[2]]
        if (!is.null(ynames[[3]]))fdnames[[3]] <- ynames[[3]]
      }
    }
}
##
## 4.  done
##
sb <- sb1
sb$beta       <- beta.
sb$fd$coefs   <- coefs
sb$fd$fdnames <- fdnames
sb

}

################################################################################

smooth.basis1 <- function (argvals=1:n, y, fdParobj,
                           wtvec=NULL,   fdnames=NULL, covariates=NULL,
                           method="chol", dfscale=1)
{
#  Arguments:
# ARGVALS  A set of N argument values, set by default to equally spaced
#             on the unit interval (0,1).
# Y        an array containing values of curves
#             If the array is a matrix, rows must correspond to argument
#             values and columns to replications, and it will be assumed
#             that there is only one variable per observation.
#             If Y is a three-dimensional array, the first dimension
#             corresponds to argument values, the second to replications,
#             and the third to variables within replications.
#             If Y is a vector, only one replicate and variable are assumed.
# FDPAROBJ A functional parameter or fdPar object.  This object
#             contains the specifications for the functional data
#             object to be estimated by smoothing the data.  See
#             comment lines in function fdPar for details.
#             This argument may also be either a FD object, or a
#             BASIS object.  In this case, the smoothing parameter
#             LAMBDA is set to 0.
# WEIGHT   A vector of N weights, set to one by default, that can
#             be used to differentially weight observations, or
#             a symmetric positive definite matrix of order N
# FDNAMES  A cell of length 3 with names for
#             1. argument domain, such as "Time"
#             2. replications or cases
#             3. the function.
# COVARIATES  A N by Q matrix Z of covariate values used to augment
#             the smoothing function, where N is the number of
#             data values to be smoothed and Q is the number of
#             covariates.  The process of augmenting a smoothing
#             function in this way is often called "semi-parametric
#             regression".  The default is the null object NULL.
# METHOD      The method for computing coefficients.  The usual method
#             computes cross-product matrices of the basis value matrix,
#             adds the roughness penalty, and uses the Choleski decomposition
#             of this to compute coefficients, analogous to using the
#             normal equations in least squares fitting.  But this approach,
#             while fast, contributes unnecessary rounding error, and the qr
#             decomposition of the augmented basis matrix is prefererable.
#             But nothing comes for free, and the computational overhead of
#             the qr approach can be a serious problem for large problems
#             (n of 1000 or more).  For this reason, the default is
#             "method" = "chol", but if 'method' == 'qr', the qr
#             decomposition is used.
# DFFACTOR A multiplier of df in GCV, set to one by default
#
# Returns a list containing:
#   FDOBJ   an object of class fd containing coefficients.
#   DF      a degrees of freedom measure.
#   GCV     a measure of lack of fit discounted for df.
#              If the function is univariate, GCV is a vector
#              containing the error  sum of squares for each
#              function, and if the function is multivariate,
#              GCV is a NVAR by NCURVES matrix.
#   COEF    the coefficient matrix for the basis function
#                expansion of the smoothing function
#   SSE     the error sums of squares.
#              SSE is a vector or matrix of the same size as
#              GCV.
#   PENMAT  the penalty matrix.
#   Y2CMAP  the matrix mapping the data to the coefficients.
#
#  This version of smooth.basis, introduced in March 2011, permits ARGVALS
#  to be a matrix, with the same dimensions as the first two dimensions of Y
#  This allows the sampling points to vary from one record to another.
#  This first section of code selects the version of smooth.basis to use
#  depending on whether ARGVALS is a vector (case 1) or a matrix (case 2)
#  The earlier version of smooth.basis is found at the end of the file where
#  it is names smooth.basis1.

#  ---------------------------------------------------------------------
#                      Check argments
#  ---------------------------------------------------------------------

#  check Y  and set nrep, nvar and ndim

if (is.vector(y)) {
  y <- matrix(y,length(y),1)
}
dimy <- dim(y)
n    <- dimy[1]

ycheck <- ycheck(y, n)
y      <- ycheck$y
y0     <- y  #  preserve a copy of Y
nrep   <- ycheck$ncurve
nvar   <- ycheck$nvar
ndim   <- ycheck$ndim
ydim   <- dim(y)

#  check ARGVALS

if (!is.numeric(argvals)) stop("'argvals' is not numeric.")
argvals <- as.vector(argvals)

#  check fdParobj

fdParobj <- fdParcheck(fdParobj)
fdobj    <- fdParobj$fd
lambda   <- fdParobj$lambda
Lfdobj   <- fdParobj$Lfd
penmat   <- fdParobj$penmat

#  check LAMBDA

if (lambda < 0) {
    warning ("Value of 'lambda' was negative  0 used instead.")
    lambda <- 0
}

#  check WTVEC

wtlist <- wtcheck(n, wtvec)
wtvec  <- wtlist$wtvec
onewt  <- wtlist$onewt
matwt  <- wtlist$matwt

# if (matwt) wtmat <- wtvec #  else wtmat <- diag(as.vector(wtvec))

#  extract information from fdParobj

nderiv   <- Lfdobj$nderiv
basisobj <- fdobj$basis
nbasis   <- basisobj$nbasis
onebasis <- rep(1,nbasis)

#  set up names for first dimension of y

tnames <- dimnames(y)[[1]]
if (is.null(tnames)) tnames <- 1:n

#  get names for basis functions

bnames <- fdParobj$fd$basis$names

#  set up matrix or array for coefficients of basis expansion,
#  as well as names for replications and, if needed, variables

if (ndim == 2)  {
    coef   <- matrix(0,nbasis,nrep)
    ynames <- dimnames(y)[[2]]
    vnames <- "value"
    dimnames(coef) <- list(bnames, ynames)
}

if (ndim == 3)  {
    coef <- array(0,c(nbasis,nrep,nvar))
    ynames <- dimnames(y)[[2]]
    vnames <- dimnames(y)[[3]]
    dimnames(coef) <- list(bnames, ynames, vnames)
}

#  check COVARIATES and set value for q, the number of covariates

if (!is.null(covariates)) {
    if (!is.numeric(covariates)) {
        stop(paste("smooth_basis_LS:covariates",
            "Optional argument COVARIATES is not numeric."))
    }
    if (dim(covariates)[1] != n) {
        stop(paste("smooth_basis_LS:covariates",
            "Optional argument COVARIATES has incorrect number of rows."))
    }
    q <- dim(covariates)[2]
} else {
    q <- 0
    beta. <- NULL
}

#  ----------------------------------------------------------------
#                set up the linear equations for smoothing
#  ----------------------------------------------------------------

#  set up matrix of basis function values

basismat <- eval.basis(as.vector(argvals), basisobj, 0)

if (method == "chol") {

  #  -----------------------------------------------------------------
  #  use the default choleski decomposition of the crossproduct of the
  #  basis value matrix plus the roughness penalty
  #  -----------------------------------------------------------------

  if (n > nbasis + q || lambda > 0) {

    #  augment BASISMAT0 and BASISMAT by the covariate matrix
    #  if it is supplied

    if (!is.null(covariates)) {
        ind1 <- 1:n
        ind2 <- (nbasis+1):(nbasis+q)
        basismat  <- as.matrix(basismat)
        basismat  <- cbind(basismat,  matrix(0,dim(basismat) [1],q))
        basismat[ind1,ind2]  <- covariates
    }

    #  Compute the product of the basis and weight matrix

    if (matwt) {
        wtfac   <- chol(wtvec)
        basisw  <- wtvec %*% basismat
    } else {
        rtwtvec <- sqrt(wtvec)
        rtwtmat <- matrix(rtwtvec,n,nrep)
        basisw  <- (wtvec %*% matrix(1,1,nbasis+q))*basismat
    }

    #  the weighted crossproduct of the basis matrix
    Bmat  <- t(basisw) %*% basismat
    #  Bmat  <- crossprod(basisw,basismat)
    Bmat0 <- Bmat

    #  set up right side of normal equations

    if (ndim < 3) {
        Dmat <- t(basisw) %*% y
        # Dmat <- crossprod(basisw,y)
    } else {
        Dmat <- array(0, c(nbasis+q, nrep, nvar))
        for (ivar in 1:nvar) {
            Dmat[,,ivar] <- crossprod(basisw,y[,,ivar])
        }
    }

    if (lambda > 0) {
      #  smoothing required, add the contribution of the penalty term
      if (is.null(penmat)) penmat <- eval.penalty(basisobj, Lfdobj)
      Bnorm   <- sqrt(sum(diag(t(Bmat0) %*% Bmat0)))
      pennorm <- sqrt(sum(penmat*penmat))
      condno  <- pennorm/Bnorm
      if (lambda*condno > 1e12) {
        lambda <- 1e12/condno
        warning(paste("lambda reduced to",lambda,
                      "to prevent overflow"))
      }
      if (!is.null(covariates)) {
        penmat <- rbind(cbind(penmat, matrix(0,nbasis,q)),
                           cbind(matrix(0,q,nbasis), matrix(0,q,q)))
      }
      Bmat   <- Bmat0 + lambda*penmat
    } else {
      penmat <- NULL
      Bmat   <- Bmat0
    }

    #  compute inverse of Bmat

    Bmat    <- (Bmat+t(Bmat))/2
    Lmat    <- try(chol(Bmat), silent=TRUE)
    if (inherits(Lmat, "try-error")) {
        Beig <- eigen(Bmat, symmetric=TRUE)
        BgoodEig <- (Beig$values>0)
        Brank <- sum(BgoodEig)
        if (Brank<dim(Bmat)[1])
          warning("Matrix of basis function values has rank ",
                  Brank, " < dim(fdobj$basis)[2] = ",
                  length(BgoodEig), "  ignoring null space")
        goodVec <- Beig$vectors[, BgoodEig]
        Bmatinv <- (goodVec %*% (Beig$values[BgoodEig] * t(goodVec)))
    } else {
        Lmatinv <- solve(Lmat)
        Bmatinv <- Lmatinv %*% t(Lmatinv)
    }

    #  compute coefficient matrix by solving normal equations

    if (ndim < 3) {
        coef <- Bmatinv %*% Dmat
        if (!is.null(covariates)) {
            beta. <- as.matrix(coef[(nbasis+1):(nbasis+q),])
            coef  <- as.matrix(coef[1:nbasis,])
        } else {
            beta. <- NULL
        }
    } else {
        coef <- array(0, c(nbasis, nrep, nvar))
        if (!is.null(covariates)) {
          beta. <- array(0, c(q, nrep, nvar))
        } else {
          beta. <- NULL
        }
        for (ivar in 1:nvar) {
  			  coefi <- Bmatinv %*% Dmat[,,ivar]
          if (!is.null(covariates)) {
            beta.[,,ivar] <- coefi[(nbasis+1):(nbasis+q),]
            coef[,,ivar] <- coefi[1:nbasis,]
          } else {
            coef[,,ivar] <- coefi
          }
        }
    }

  } else {

    if (n == nbasis + q) {

      #  code for n == nbasis, q == 0, and lambda == 0
      if (ndim==2)
          coef <- solve(basismat, y)
      else
          for (ivar in 1:var)
            coef[1:n, , ivar] <- solve(basismat, y[,,ivar])
      penmat  <- NULL
    } else {

      #  n < nbasis+q:  this is treated as an error

      stop("The number of basis functions = ", nbasis+q, " exceeds ",
              n, " = the number of points to be smoothed.")
    }
  }

} else {

  #  -------------------------------------------------------------
  #  computation of coefficients using the qr decomposition of the
  #  augmented basis value matrix
  #  -------------------------------------------------------------

  if (n > nbasis || lambda > 0) {

    #  Multiply the basis matrix and the data pointwise by the square root
    #  of the weight vector if the weight vector is not all ones.
    #  If the weights are in a matrix, multiply the basis matrix by its
    #  Choleski factor.

    if (!onewt) {
        if (matwt) {
          wtfac <- chol(wtvec)
          basismat.aug <- wtfac %*% basismat
          if (ndim < 3) {
            y <- wtfac %*% y
          } else {
            for (ivar in 1:nvar) {
                y[,,ivar] <- wtfac %*% y[,,ivar]
            }
          }
        } else {
          rtwtvec  <- sqrt(wtvec)
          basismat.aug <- matrix(rtwtvec,n,nbasis) * basismat
          if (ndim < 3) {
            y <- matrix(rtwtvec,n,nrep) * y
          } else {
            for (ivar in 1:nvar) {
                y[,,ivar] <- matrix(rtwtvec,n,nrep) * y[,,ivar]
            }
          }
        }
    } else {
      basismat.aug <- basismat
    }

    #  set up additional rows of the least squares problem for the
    #  penalty term.

    if (lambda > 0) {
        if (is.null(penmat)) penmat <- eval.penalty(basisobj, Lfdobj)
        eiglist <- eigen(penmat)
        Dvec    <- eiglist$values
        Vmat    <- eiglist$vectors
        #  Check that the lowest eigenvalue in the series that is to be
        #  kept is positive.
        neiglow <- nbasis - nderiv
        naug    <- n + neiglow
        if (Dvec[neiglow] <= 0) {
            stop(paste("smooth_basis:eig",
                       "Eigenvalue(NBASIS-NDERIV) of penalty matrix ",
                       "is not positive check penalty matrix."))
        }
        #  Compute the square root of the penalty matrix in the subspace
        #  spanned by the first N - NDERIV eigenvectors
        indeig <- 1:neiglow
        penfac <- Vmat[,indeig] %*% diag(sqrt(Dvec[indeig]))
        #  Augment basismat by sqrt(lambda)*t(penfac)
        basismat.aug <- rbind(basismat.aug, sqrt(lambda)*t(penfac))
        #  Augment data vector by n - nderiv 0's
        if (ndim < 3) {
            y <- rbind(y, matrix(0,nbasis-nderiv,nrep))
        } else {
            y <- array(0,c(ydim[1]+nbasis-nderiv,ydim[2],ydim[3]))
            y[1:ydim[1],,] <- y0
            ind1 <- (1:(nbasis-nderiv)) + ydim[1]
            for (ivar in 1:nvar) {
                y[ind1,,ivar] <- matrix(0,nbasis-nderiv,nrep)
            }
        }
    } else {
        penmat <- NULL
    }

    #  augment BASISMAT0 and BASISMAT by the covariate matrix
    #  if it is supplied

    if (!is.null(covariates)) {
        ind1 <- 1:n
        ind2 <- (nbasis+1):(nbasis+q)
        basismat.aug  <- cbind(basismat.aug,  matrix(0,naug,q))
        if (!onewt) {
            if (matwt) {
                basismat.aug[ind1,ind2]  <- wtfac %*% covariates
            } else {
                wtfac <- matrix(rtwtvec,n,q)
                basismat.aug[ind1,ind2]  <- wtfac*covariates
            }
        } else {
            basismat.aug[ind1,ind2]  <- covariates
        }
        penmat <- rbind(cbind(penmat,             matrix(0,nbasis,q)),
                        cbind(matrix(0,q,nbasis), matrix(0,q,q)))
    }

    #  solve the least squares problem using the QR decomposition with
    #  one iteration to improve accuracy

    qr <- qr(basismat.aug)
    if (ndim < 3) {
        coef <- qr.coef(qr,y)
        if (!is.null(covariates)) {
            beta. <- coef[ind2,]
            coef  <- coef[1:nbasis,]
        } else {
            beta. <- NULL
        }
    } else {
        coef <- array(0, c(nbasis, nrep, nvar))
        if (!is.null(covariates)) {
            beta. <- array(0, c(q,nrep,nvar))
        } else {
            beta. <- NULL
        }
        for (ivar in 1:nvar) {
            coefi <- qr.coef(qr,y[,,ivar])
            if (!is.null(covariates)) {
                beta.[,,ivar] <- coefi[ind2,]
                coef[,,ivar] <- coefi[1:nbasis,]
            } else {
                coef[,,ivar] <- coefi
            }
        }
    }

  } else {

    if (n == nbasis + q) {

      #  code for n == nbasis and lambda == 0

      {
        if (ndim==2)
          coef <- solve(basismat, y)
        else
          for (ivar in 1:var)
            coef[,,ivar] <- solve(basismat, y[,,ivar])
      }
      penmat <- NULL

    } else {

      stop(paste("The number of basis functions = ", nbasis, " exceeds ",
              n, " = the number of points to be smoothed.  "))
    }
  }

}

#  ----------------------------------------------------------------
#            compute SSE, yhat, GCV and other fit summaries
#  ----------------------------------------------------------------

#  compute map from y to c

if (onewt) {
    temp   <- t(basismat) %*% basismat
    if (lambda > 0) {
        temp <- temp + lambda*penmat
    }
    L      <- chol(temp)
    MapFac <- solve(t(L),t(basismat))
    y2cMap <- solve(L,MapFac)
} else {
    if(matwt){
        temp <- t(basismat) %*% wtvec %*% basismat
    } else {
        temp <- t(basismat) %*% (as.vector(wtvec)*basismat)
    }
#
    if  (lambda > 0) {
        temp <- temp + lambda*penmat
    }
    L      <- chol((temp+t(temp))/2)
    MapFac <- solve(t(L),t(basismat))
    if(matwt){
        y2cMap <- solve(L, MapFac%*%wtvec)
    } else {
        y2cMap <- solve(L,MapFac*rep(as.vector(wtvec), e=nrow(MapFac)))
    }
}

#  compute degrees of freedom of smooth

    df. <- sum(diag(y2cMap %*% basismat))

#  compute error sum of squares

if (ndim < 3) {
    yhat <- basismat[,1:nbasis] %*% coef
    SSE  <- sum((y[1:n,] - yhat)^2)
    if (is.null(ynames)) ynames <- dimnames(yhat)[[2]]
} else {
    SSE <- 0
    yhat <- array(0,c(n, nrep, nvar))
    dimnames(yhat) <- list(dimnames(basismat)[[1]],
                           dimnames(coef)[[2]],
                           dimnames(coef)[[3]])
    for (ivar in 1:nvar) {
      yhat[,,ivar] <- basismat[,1:nbasis] %*% coef[,,ivar]
      SSE <- SSE + sum((y[1:n,,ivar] - yhat[,,ivar])^2)
    }
    if (is.null(ynames))ynames <- dimnames(yhat)[[2]]
    if (is.null(vnames))vnames <- dimnames(yhat)[[2]]
}
if (is.null(ynames)) ynames <- paste("rep", 1:nrep, sep="")
if (is.null(vnames)) vnames <- paste("value", 1:nvar, sep="")

#  compute  GCV index

if (!is.null(df.) && df. < n) {
    if (ndim < 3) {
      gcv <- rep(0,nrep)
      for (i in 1:nrep) {
        SSEi <- sum((y[1:n,i] - yhat[,i])^2)
        gcv[i] <- (SSEi/n)/((n - df.)/n)^2
      }
      if (ndim>1)names(gcv) <- ynames
    } else {
      gcv <- matrix(0,nrep,nvar)
      for (ivar in 1:nvar) {
        for (i in 1:nrep) {
          SSEi <- sum((y[1:n,i,ivar] - yhat[,i,ivar])^2)
          gcv[i,ivar] <- (SSEi/n)/((n - df.)/n)^2
        }
      }
      dimnames(gcv) <- list(ynames, vnames)
    }
} else {
    gcv <- NULL
}

#------------------------------------------------------------------
#       Set up the functional data objects for the smooths
#  ------------------------------------------------------------------

#  set up default fdnames

if (is.null(fdnames)) {
    fdnames <- list(time=tnames, reps=ynames, values=vnames)
}

#  set up the functional data object

if (ndim < 3) {
    coef  <- as.matrix(coef)
    fdobj <- fd(coef[1:nbasis,],  basisobj, fdnames)
} else {
    fdobj <- fd(coef[1:nbasis,,], basisobj, fdnames)
}

#  return penalty matrix to original state if there were covariates

if (!is.null(penmat) && !is.null(covariates))
                 penmat <- penmat[1:nbasis,1:nbasis]

#  assemble the fdSmooth object returned by the function

smoothlist <- list(fd=fdobj, df=df., gcv=gcv, beta=beta.,
                   SSE=SSE, penmat=penmat, y2cMap=y2cMap,
                   argvals=argvals, y=y0)

return(smoothlist)

}

