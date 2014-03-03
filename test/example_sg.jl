using JAGS, SixelGraphics

jl = JAGSLibrary()
jm = JAGSModel(jl,joinpath(Pkg.dir("JAGS"),"test/bap.bug"))

d = readdlm("sim.txt",' ')
nobs = size(d,1)
ids = iround(d[:,1])
nid = ids[end]

set_data(jm,:ID,d[:,1])
set_data(jm,:DV,d[:,2]-d[:,3])
set_data(jm,:NOBS,nobs)
set_data(jm,:NID,nid)

compile(jm)
print_variable_names(jm)
initialize(jm)
update(jm,1000)
set_monitors(jm,["uloa" "mu" "lloa"])

update(jm,100000)

println("\nStatistics of the monitored values:")
sm = get_stats(jm)
showcompact(sm)
println("")

for i=1:get_monitors_size(jm)
  name = get_monitor_name(jm,i)
  v = get_monitored_values(jm,i,1)
  s = sixelplot(v,xsize=384,ysize=180,typ='p',pch=0,xlab="iter",ylab=name,showsixels=false)
  n = get_monitor_iter(jm,i)
  q = sm[name]
  sixelplot(s,[1 n],[q[4] q[4]],showsixels=false)
  sixelplot(s,[1 n],[q[5] q[5]],showsixels=false)
  sixelplot(s,[1 n],[q[6] q[6]])
end
