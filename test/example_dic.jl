using JAGS

jl = JAGSLibrary()
jm = JAGSModel(jl,joinpath(Pkg.dir("JAGS"),"test/bap.bug"),nchain=2)

d = readdlm("sim.txt",' ')
nobs = size(d,1)
ids = iround(d[:,1])
nid = ids[end]

set_data(jm,:ID,d[:,1])
set_data(jm,:DV,d[:,2]-d[:,3])
set_data(jm,:NOBS,nobs)
set_data(jm,:NID,nid)

compile(jm)
initialize(jm)
update(jm,1000)

load_module("dic")
d = dic(jm,10000)
showcompact(d)
println("")

