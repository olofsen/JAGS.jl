JAGS: A Julia interface to JAGS

The package provides a shared library as an interface between Julia
and JAGS, just like "rjags".  The script "lib/make.sh" should be run
to compile the library and tell the package where to find JAGS's modules.
Modules are currently loaded using "libltdl", but perhaps this is not
necessary (rjags does not seem to need this).

The types and methods defined in "JAGS.jl" are best illustrated with
(and were at present only tested with) the example in the "test" directory.

Zero- and one-dimensional data may be passed to JAGS using the "set_data"
function. DataFrames may be useful here; NAs are not yet implemented.

The functions in the shared library and the package are incomplete, e.g.,
with respect to monitor types and ranges, factories, and cleaning up.

The checking of adaptation and errors is most likely also incomplete;
this may lead to erroneous results and crashes.

Basic statistics are calculated using "coef" and some simple graphs
are created in the example using package SixelGraphics, which is
admittedly obscure, but handy with some terminals (see "example.png").

Installation:
Pkg.clone("git://github.com/olofsen/JAGS.jl")
Pkg.clone("git://github.com/olofsen/SixelGraphics.jl")
