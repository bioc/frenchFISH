# return TRUE if all values in df are non-negative integers; otherwise return FALSE
is.all.nonnegative.integers<-function(df)
{
  for (i in 1:nrow(df)) {
    for (j in 1:ncol(df)) {
      val = df[i,j]
      if(is.na(val)) {
        next # NA and NaN are allowed in probeCounts and handled later
      }
      if(!is.numeric(val)) {
        return(FALSE)
      }
      if((val < 0) | (val != round(val))) {
        return(FALSE)
      }
    }
  }
  return(TRUE)
}

#get the average volume of nucleus sampled given the nucleus radius and section height
getAverageVolumeFrac<-function(r,h)
{
  Vavg=pi*h*(2/3*r^2 +r*h/3 - h^2/6)
  Vsphere=4/3*pi*r^3
  return(Vavg/Vsphere)
}

#get the maximum possible volume of nucleus sampled given the nucleus radius and section height
getMaxVolumeFrac<-function(r,h)
{
  d=0
  hh=h/2
  v=pi*hh*(r^2 -d^2 -d*hh -(1/3)*(hh^2))
  Vmax=2*v
  Vsphere=(4/3)*pi*(r^3)
  return(Vmax/Vsphere)
}

#get the minimum possible volume of nucleus sampled given the nucleus radius and section height
getMinVolumeFrac<-function(r,h)
{
  d=r-h
  Vmin=pi*h*(r^2 - d^2 - d*h - (1/3)*(h^2))
  Vsphere=(4/3)*pi*(r^3)
  return(Vmin/Vsphere)
}

#get the fraction of the nucleus sampled for a specified distance from the midpoint
getVsegFrac<-function(d,h,r)
{
  Vseg=pi*h*(r^2-d^2-h^2/12)
  Vsphere=4/3*pi*r^3
  return(Vseg/Vsphere)
}

#' FrenchFISH function for generating volume adjusted spot counts from spots
#' which have been manually counted (uses a Markov chain Monte Carlo method).
#'
#' @param probeCounts A dataframe of manual spot counts with columns for probes and rows for nuclei
#' @param radius The cell radius (must be measured in same unit as \code{height})
#' @param height The section height (must be measured in same unit as \code{radius})
#' @return The volume adjusted spot counts for each probe that have been generated using MCMC modelling
#' @export
#' @examples
#' manualCountsEstimates<-getManualCountsEstimates(data.frame(red=c(0,2,4), green=c(5,3,1), blue=c(3,0,2)), 8, 4)
getManualCountsEstimates<-function(probeCounts, radius, height)
{

  if(!is.numeric(radius)) {
    stop("radius must be numeric")
  }
  if(!is.numeric(height)) {
    stop("height must be numeric")
  }
  if(radius < 0) {
    stop("radius must be greater than 0")
  }
  if(height < 0) {
    stop("height must be greater than 0")
  }
  if(!is.data.frame(probeCounts)) {
    stop("probeCounts must be a dataframe")
  }
  if(ncol(probeCounts) < 1) {
    stop("probeCounts must have at least one column")
  }
  if(nrow(probeCounts) < 1) {
    stop("probeCounts must have at least one row")
  }
  #if(any(is.na(probeCounts))) {
  #  stop("probeCounts cannot have any NA or NaN values")
  #}
  if(any(is.infinite(as.matrix(probeCounts)))) {
    stop("probeCounts cannot have any Inf or -Inf values")
  }
  if(!is.all.nonnegative.integers(probeCounts)) {
    stop("All non-NA/NaN counts in probeCounts must be non-negative integers")
  }

  avg<-getMaxVolumeFrac(radius, height)
  countEstimates<-c()

  for(i in 1:ncol(probeCounts))
  {
    prCts <- probeCounts[,i]
    no_na_probeCounts <- prCts[!is.na(prCts)] # get probe counts column with all NA and NaN entries removed

    res<-c()
    # if all counts for a probe are NA or NaN, make estimates NA
    if(length(no_na_probeCounts) == 0) {
      #stop("All probes must have a count")
      #stop("Probe ", colnames(probeCounts)[i], " has no counts")
      res<-data.frame(X2.5 = NA, X25 = NA, X50 = NA, X75 = NA, X97.5 = NA)
    }
    else {
      posterior_aqua<-MCMCpack::MCpoissongamma(no_na_probeCounts,0.01,0.01,5000)/avg
      qtls<-summary(posterior_aqua)$quantiles
      res<-data.frame(X2.5 = c(qtls[1]), X25 = c(qtls[2]), X50 = c(qtls[3]), X75 = c(qtls[4]), X97.5 = c(qtls[5]))
    }
    # Append probe results to all results
    rownames(res)<-colnames(probeCounts)[i]
    countEstimates<-rbind(countEstimates, res)
  }
  return(data.frame(Probe=row.names(countEstimates), countEstimates, row.names = NULL))
}

#helper function to convert spot counts and nuclear area measurements into continuous events for PP estimation
generatePPdat<-function(area,spots)
{
  #print('generatePPdat')
  #print(area)
  #print(spots)
  indat<-0
  for(i in 1:length(area))
  {
    #print(spots[i])
    if(spots[i]==0)
    {
      # is this really the desired behavior? see generatePPdat(c(500),c(0)) vs generatePPdat(c(500),c(1)) vs generatePPdat(c(500,500),c(1,0))
      # would a continue statement be better behavior?
      indat[length(indat)]<-indat[length(indat)]+area[i]
    }
    else
    {
      for(k in 1:spots[i])
      {
        indat<-c(indat,area[i]/spots[i])
      }
    }
  }
  return(indat)
}

#' FrenchFISH function for generating Poisson point estimates of spot counts from
#' spot counts which have been automatically generated.
#'
#' @param probeCounts A dataframe where the first column contains the areas of the nuclear blobs (this column must be named "area" and the unit of its entries must be the square of the unit used to measure \code{radius} and \code{height}) and the remaining columns (one per probe) contain the spot counts for different probes in each nuclear blob
#' @param radius The cell radius (must be measured in same unit as \code{height})
#' @param height The section height (must be measured in same unit as \code{radius})
#' @return The Poisson point estimates of with spot counts for each probe
#' @export
#' @examples
#' automaticCountsEstimates<-getAutomaticCountsEstimates(data.frame(area=c(250,300,450), red=c(0,2,4), green=c(5,3,1), blue=c(3,0,2)), 8, 4)
getAutomaticCountsEstimates<-function(probeCounts, radius, height)
{
  if(!is.numeric(radius)) {
    stop("radius must be numeric")
  }
  if(!is.numeric(height)) {
    stop("height must be numeric")
  }
  if(radius < 0) {
    stop("radius must be greater than 0")
  }
  if(height < 0) {
    stop("height must be greater than 0")
  }
  if(!is.data.frame(probeCounts)) {
    stop("probeCounts must be a dataframe")
  }
  if(nrow(probeCounts) < 1) {
    stop("probeCounts must have at least one row")
  }
  if(ncol(probeCounts) < 2) {
    stop("probeCounts must have at least one column for nuclear blob area and one column for spot counts at a probe")
  }
  if(colnames(probeCounts)[1] != "area") {
    stop('First column of probeCounts must be named "area" and contain nuclear blob areas')
  }
  if(any(is.na(probeCounts$area))) {
    stop("Areas in first column cannot have any NA or NaN values")
  }
  if(any(is.infinite(as.matrix(probeCounts)))) {
    stop("probeCounts cannot have any Inf or -Inf values")
  }
  if(!is.all.nonnegative.integers(data.frame(probeCounts[,-1]))) {
    stop("All non-NA/NaN counts in probeCounts must be non-negative integers")
  }
  if(any(probeCounts$area <= 0)) {
    stop("All values in area column must be greater than 0")
  }

  cellarea<-pi*(radius^2)
  adjustFact<-getAverageVolumeFrac(radius,height)

  countEstimates<-c()
  for(i in 2:ncol(probeCounts))
  {
    prCts <- probeCounts[,i]
    no_na_probeCounts <- prCts[!is.na(prCts)] # get probe counts column with all NA and NaN entries removed
    no_na_area <- probeCounts$area[!is.na(prCts)] # get the area column with all entries removed where probe counts are NA or NaN

    # if all counts for a probe are NA or NaN, make estimates NA
    if(length(no_na_probeCounts) == 0) {
      #stop("All probes must have a count")
      #stop("Probe ", colnames(probeCounts)[i], " has no counts")
      res<-data.frame(lowCI=c(NA), median=c(NA), highCI=c(NA))
    }
    else {
      ppindat<-generatePPdat(no_na_area, no_na_probeCounts)
      ppcumsum<-cumsum(ppindat)/cellarea # remove NA and NaA values from ppindat before cumsum
      PPestimate<-NHPoisson::fitPP.fun(posE=ppcumsum,nobs=max(ppcumsum),start=list(b0=0),modCI=TRUE,CIty="Transf",dplot=FALSE)
      res<-data.frame(lowCI=PPestimate@LIlambda[1],median=exp(PPestimate@coef),highCI=PPestimate@UIlambda[1])
    }
    #print(res)
    # Append probe results to all results
    rownames(res)<-colnames(probeCounts)[i]
    countEstimates<-rbind(countEstimates,res)
  }
  countEstimates<-countEstimates/adjustFact
  return(data.frame(Probe=row.names(countEstimates), countEstimates, row.names = NULL))
}