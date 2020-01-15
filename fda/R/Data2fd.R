Data2fd <- function(argvals=NULL, y=NULL, basisobj=NULL, nderiv=NULL,
                    lambda=3e-8/diff(as.numeric(range(argvals))),
                    fdnames=NULL, covariates=NULL, method="chol",
                    dfscale=1)
{
  
  stop("Function Data2fd has been removed from the fda package while we are 
reviewing its status.  Please use function smooth.basis to smooth your data.")
  
}
