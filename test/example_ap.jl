using JAGS, ASCIIPlots

jl = JAGSLibrary()
jm = JAGSModel(jl,joinpath(Pkg.dir("JAGS"),"test/bap.bug"))

d = readdlm("sim.txt",' ')
nobs = size(d,1)
ids = iround(d[:,1])
nid = ids[end]

set_data(jm,"ID",d[:,1])
set_data(jm,"DV",d[:,2]-d[:,3])
set_data(jm,"NOBS",nobs)
set_data(jm,"NID",nid)

compile(jm)
print_variable_names(jm)
initialize(jm)
update(jm,1000)
set_monitors(jm,["uloa" "mu" "lloa"], thin=100)

update(jm,6000) # considering resolution

println("\nStatistics of the monitored values:")
sm = coef(jm)
showcompact(sm)
println("")

for i=1:get_monitors_size(jm)
  name = get_monitor_name(jm,i)
  println(name)
  v = get_monitored_values(jm,i,1)
  print(scatterplot(v,sym='.'))
end
