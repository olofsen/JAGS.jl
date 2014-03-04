JAGS.jl: A Julia interface to JAGS

The package provides a shared library as an interface between Julia
and JAGS, just like "rjags".  The script "make.sh" should be run (in "lib")
to compile the library and tell the package where to find JAGS's modules.
Modules are currently loaded using "libltdl", as does JAGS's terminal.

The types and methods defined in "JAGS.jl" are best illustrated with
(and were at present only tested with) the example in the "test" directory.

Zero- and one-dimensional data may be passed to JAGS using the "set_data"
function. DataFrames may be useful here (see the DataFrames version of the
example); NA values are converted to their JAGS representation.

Initial values may also be specified using DataFrames (see the
inits version of the example).

The functions in the shared library and the package are incomplete, e.g.,
with respect to monitor types and ranges, factories, and cleaning up.

The checking of adaptation and errors is most likely still incomplete;
this may lead to erroneous results and crashes.

Basic statistics are calculated with "get_stats", and some simple graphs
are created in the example using package SixelGraphics, which is
admittedly obscure, but handy with some terminals. See "example.png",
or the ASCIIPlots version.

Installation (under Linux):
<ul>
<li>Pkg.clone("git://github.com/olofsen/JAGS.jl")</li>
<li>Optionally add "DataFrames"</li>
<li>Optionally clone "SixelGraphics" or add "ASCIIPlots"</li>
<li>Install libltdl</li>
<li>Run make.sh in lib</li>
</ul>
