using JAGS, DataFrames, SixelGraphics

import JAGS.set_data, JAGS.set_inits

function set_data(jm::JAGSModel, df::DataFrame)
  for name in names(df)
    set_data(jm, name, df[name].data, df[name].na)
  end
end

function set_inits(jm::JAGSModel, df::DataFrame)
  for name in names(df)
    set_init(jm, name, df[name].data)
  end
  set_inits(jm)
end

jl = JAGSLibrary()

d = readdlm("sim.txt",' ')
nobs = size(d,1)
ids = iround(d[:,1])
nid = ids[end]

df = DataFrame()
df[:ID] = d[:,1]
df[:DV] = d[:,2]-d[:,3]

inits = DataFrame()
inits[:mu] = 10.

jm = JAGSModel(jl,joinpath(Pkg.dir("JAGS"),"test/bap.bug"))
set_data(jm,df)
set_data(jm,:NOBS,nobs)
set_data(jm,:NID,nid)
compile(jm)
set_inits(jm,inits)
initialize(jm)
set_monitors(jm,["mu"])
update(jm,10,false)

v = get_monitored_values(jm,1,1)
s = sixelplot(v,showsixels=false)
sixelplot(s,v,typ='p')
