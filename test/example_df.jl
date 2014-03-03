using JAGS, DataFrames

import JAGS.set_data

function set_data(jm::JAGSModel, df::DataFrame)
  for name in names(df)
    set_data(jm, name, df[name].data, df[name].na)
  end
end

jl = JAGSLibrary()

d = readdlm("sim.txt",' ')
nobs = size(d,1)
ids = iround(d[:,1])
nid = ids[end]

df = DataFrame()

df[:ID] = d[:,1]
df[:DV] = d[:,2]-d[:,3]

df[:DV][1] = 0

jm = JAGSModel(jl,joinpath(Pkg.dir("JAGS"),"test/bap.bug"))
set_data(jm,df)
set_data(jm,:NOBS,nobs)
set_data(jm,:NID,nid)
compile(jm)
initialize(jm)
update(jm,1000)
set_monitors(jm,["DV"])
update(jm,10000)
v = get_monitored_values(jm,1,1)
println("\nStatistics of DV[1]:")
showcompact(get_stats(v[1,:]))
println("")

df[:DV][1] = NA

jm = JAGSModel(jl,joinpath(Pkg.dir("JAGS"),"test/bap.bug"))
set_data(jm,df)
set_data(jm,:NOBS,nobs)
set_data(jm,:NID,nid)
compile(jm)
initialize(jm)
update(jm,1000)
set_monitors(jm,["DV"])
update(jm,10000)
v = get_monitored_values(jm,1,1)
println("\nStatistics of DV[1]:")
showcompact(get_stats(v[1,:]))
println("")
