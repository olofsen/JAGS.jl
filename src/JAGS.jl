module JAGS

export JAGSLibrary, JAGSModel, load_module, set_data, compile, initialize,
       is_adapting, check_adaptation, adapt, update, print_variable_names,
       set_init, set_inits,
       set_monitors, clear_monitors, get_monitors_size, get_monitor_name,
       get_monitor_iter, get_monitor_nvalue, get_monitored_values, print_monitor_names,
       print_module_names, get_stats, dic, get_iter, get_nchain

const shlib = joinpath(Pkg.dir("JAGS"),"lib/jags.so")
include("modpath.jl")

type JAGSLibrary
  jc::Ptr{Void}
  function JAGSLibrary()
    if ccall( (:lt_dlinit, :libltdl), Bool, ()); error("unable to initialize libltdl"); end
    ccall( (:lt_dladdsearchdir, "libltdl"), Cint, (Ptr{Uint8},), modpath)
    println("Linked to JAGS ", get_version())
    load_module("basemod")
    load_module("bugs")
    new(convert(Ptr{Void}, 0))
  end
end

type JAGSModel
  ji::Ptr{Void}
  filnam::ASCIIString
  nchain::Int
  status::Symbol
  JAGSModel(jl::JAGSLibrary, filnam::ASCIIString; nchain=1) =
    new(make_console(jl), filnam, nchain, :assigned)
end

function make_console(jl::JAGSLibrary)
  if jl.jc!=convert(Ptr{Void}, 0)
    ccall( (:clear_console, shlib), Void, (Ptr{Void},), jl.jc)
  end
  jl.jc = ccall( (:make_console, shlib), Ptr{Void}, ())
end

function check_model(jm::JAGSModel)
  status::Bool
  status = ccall( (:check_model, shlib), Bool, (Ptr{Void},Ptr{Uint8}), jm.ji, jm.filnam)
  if status; jm.status=:model_checked; end
end

function compile(jm::JAGSModel)
  status::Bool
  check_model(jm)
  if jm.status!=:model_checked; return; end
  status = ccall( (:compile, shlib), Bool, (Ptr{Void},Cint,Bool), jm.ji, jm.nchain, true)
  if status; jm.status=:model_compiled; end
end

function initialize(jm::JAGSModel)
  status::Bool
  if jm.status!=:model_compiled; return; end
  status = ccall( (:initialize, shlib), Bool, (Ptr{Void},), jm.ji)
  if status; jm.status=:model_initialized; end
end

function update(jm::JAGSModel, niter::Int)
  status::Bool
  if is_adapting(jm)
    niter2 = div(niter,2)
    status = update(jm, niter2, true)
    if !status; return status; end
    if !check_adaptation(jm); warn("Adaptation incomplete"); end
    adapt_off(jm)
    status = update(jm, niter-niter2, false)
    if !status; return status; end
  else
    status = update(jm, niter, false)
    if !status; return status; end
  end
  jm.status = :model_burnt_in
  return true
end

function update(jm::JAGSModel, niter::Int, adapting::Bool)
  if adapting; mode="Adapting"; else mode="Updating"; end
  status = true
  i = 0
  if niter>=100
    istep = iround(niter/100)
    iiter = istep
    idone = 0
    while idone<niter
      if idone+istep>niter; iiter=niter-idone; end
      print('\r',mode,": ",i,'%')
      status = ccall( (:update, shlib), Bool, (Ptr{Void},Cint), jm.ji, iiter)
      if !status; break; end
      idone += iiter
      i += 1
    end
    println('\r',mode,": ",i,"% done")
  else
    status = ccall( (:update, shlib), Bool, (Ptr{Void},Cint), jm.ji, niter)
    idone = niter
    println(mode,": done")
  end
  return status
end

# data

function set_data(jm::JAGSModel, name::Symbol, value::Int64)
  ccall( (:to_sarray, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Cint), jm.ji, string(name), &value, 1)
end

function set_data(jm::JAGSModel, name::Symbol, value::Float64)
  ccall( (:to_sarray, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Cint), jm.ji, string(name), &value, 1)
end

function set_data(jm::JAGSModel, name::Symbol, values::Array{Int64})
  ccall( (:to_sarray, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Cint), jm.ji, string(name), convert(Array{Cdouble},values), length(values))
end

function set_data(jm::JAGSModel, name::Symbol, values::Array{Float64})
  ccall( (:to_sarray, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Cint), jm.ji, string(name), values, length(values))
end

function set_data(jm::JAGSModel, name::Symbol, values::Array{Float64}, na::BitArray{1})
  ccall( (:to_sarray_na, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Ptr{Bool},Cint), jm.ji, string(name), values, convert(Array{Cint},na), length(values))
end

function set_data(jm::JAGSModel, name::Symbol, values::Array{Int64}, na::BitArray{1})
  ccall( (:to_sarray_na, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Ptr{Bool},Cint), jm.ji, string(name), convert(Array{Cdouble},values), convert(Array{Cint},na), length(values))
end

# modules

function load_module(name::ASCIIString)
  status::Bool
  h::Ptr{Void}
  print("Loading module: ",name,':')
  h = ccall( (:lt_dlopenext, :libltdl), Ptr{Void}, (Ptr{Uint8},), name)
  if h==convert(Ptr{Void}, 0)
    println(" failed")
    return false
  end
  status = ccall( (:load_module, shlib), Bool, (Ptr{Uint8},), name)
  if !status
    println(" failed")
    return false
  end
  println(" ok")
  return true
end

function get_modules_size()
  return ccall( (:get_modules_size, shlib), Cint, ())
end

function get_module_name(i::Int)
  p = ccall( (:get_module_name, shlib), Ptr{Cchar}, (Cint,), i-1)
  name = bytestring(p)
end

function print_module_names()
  print("Module names:")
  for i=1:get_modules_size()
    print(' ',get_module_name(i))
  end
  println('\n')
end

# variables

function get_variables_size(jm::JAGSModel)
  return ccall( (:get_variables_size, shlib), Cint, (Ptr{Void},), jm.ji)
end

function get_variable_name(jm::JAGSModel, i::Int)
  p = ccall( (:get_variable_name, shlib), Ptr{Cchar}, (Ptr{Void},Cint), jm.ji, i-1)
  name = bytestring(p)
end

function print_variable_names(jm::JAGSModel)
  print("Variable names:")
  for i=1:get_variables_size(jm)
    print(' ',get_variable_name(jm,i))
  end
  println('\n')
end

# inits

function set_init(jm::JAGSModel, name::Symbol, value::Float64)
  ccall( (:to_parameter_sarray, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Cint), jm.ji, string(name), &value, 1)
end

function set_init(jm::JAGSModel, name::Symbol, values::Array{Float64})
  ccall( (:to_parameter_sarray, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Cint), jm.ji, string(name), values, length(values))
end

function set_inits(jm::JAGSModel)
  status::Bool
  status = ccall( (:set_parameters, shlib), Bool, (Ptr{Void},Cint), jm.ji, get_nchain(jm))
end

# monitors

function set_monitors(jm::JAGSModel, names::Array{ASCIIString}; thin=1, mtype="trace")
  status::Bool
  if jm.status!=:model_burnt_in; warn("model is not burnt-in"); end
  status = ccall( (:set_monitors, shlib), Bool, (Ptr{Void},Ptr{Ptr{Uint8}},Cint,Cint,Ptr{Uint8}), jm.ji, names, length(names), thin, mtype)
end

function clear_monitors(jm::JAGSModel)
  for i=1:get_monitors_size(jm)
    clear_monitor(jm, get_monitor_name(jm, i))
  end
end

function clear_monitor(jm::JAGSModel, name::ASCIIString; mtype="trace")
  ccall( (:clear_monitor, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Uint8}), jm.ji, name, mtype)
end

function get_monitor_name(jm::JAGSModel, i::Int)
  p = ccall( (:get_monitor_name, shlib), Ptr{Cchar}, (Ptr{Void},Cint), jm.ji, i-1)
  name = bytestring(p)
end

function get_monitor_iter(jm::JAGSModel, i::Int)
  iter::Int
  iter = ccall( (:get_monitor_iter, shlib), Cint, (Ptr{Void},Cint), jm.ji, i-1)
end

function get_monitor_nvalue(jm::JAGSModel, i::Int)
  nvalue::Int
  nvalue = ccall( (:get_monitor_nvalue, shlib), Cint, (Ptr{Void},Cint), jm.ji, i-1)
end

function get_monitors_size(jm::JAGSModel)
  if jm.status!=:model_burnt_in; return 0; end
  return ccall( (:get_monitors_size, shlib), Cint, (Ptr{Void},), jm.ji)
end

function get_monitored_values(jm::JAGSModel, i::Int, ichain::Int)
  p::Ptr{Cdouble}
  iter::Int
  nvalue::Int
  m::Int
  iter = get_monitor_iter(jm, i)
  nvalue = get_monitor_nvalue(jm, i)
  p = ccall( (:get_monitored_values, shlib), Ptr{Cdouble}, (Ptr{Void},Cint,Cint), jm.ji, i-1, ichain-1)
  pa = pointer_to_array(p, nvalue, false)
  if nvalue<=iter
    return pa
  else
    m = div(nvalue,iter)
    return reshape(pa,m,iter)
  end
end

function print_monitor_names(jm::JAGSModel)
  print("Monitor names:")
  for i=1:get_monitors_size(jm)
    print(' ',get_monitor_name(jm,i))
  end
  println('\n')
end

function get_stats(v::Array{Float64})
  {:length=>length(v), :mean=>mean(v[:]), :std=>std(v[:]), :qlo=>quantile(v[:],0.025), :median=>quantile(v[:],0.5), :qhi=>quantile(v[:],0.975)}
end

function get_stats(jm::JAGSModel, i::Int, ichain::Int)
  v = get_monitored_values(jm,i,ichain)
  get_stats(v)
end

function get_stats(jm::JAGSModel; ichain=1)
  { get_monitor_name(jm,i) => get_stats(jm,i,ichain) for i=1:get_monitors_size(jm) }
end

# adaptation

function adapt(jm::JAGSModel, nadapt::Int)
  if is_adapting(jm)
    update(jm, nadapt, true)
  else
    warn("model is not adapting")
  end
end

function check_adaptation(jm::JAGSModel)
  status::Bool
  status = ccall( (:check_adaptation, shlib), Bool, (Ptr{Void},), jm.ji)
end

function is_adapting(jm::JAGSModel)
  status::Bool
  status = ccall( (:is_adapting, shlib), Bool, (Ptr{Void},), jm.ji)
end

function adapt_off(jm::JAGSModel)
  ccall( (:adapt_off, shlib), Void, (Ptr{Void},), jm.ji)
end

# dic

function dic(jm::JAGSModel, niter::Int; ptype="popt")
  p = convert(Ptr{Cdouble}, 0)
  iter::Int
  iter = 0  
  deviance = 0.
  penalty = 0.
  set_monitors(jm, ["deviance" ptype], mtype="mean")
  update(jm, niter)
  for i=1:get_monitors_size(jm)
    name = get_monitor_name(jm,i)
    if name=="deviance"
      deviance = sum(get_monitored_values(jm,i,1))
      clear_monitor(jm, name)
    elseif name==ptype
      penalty = sum(get_monitored_values(jm,i,1))
      clear_monitor(jm, name)
    end
  end
  {:deviance=>deviance, :penalty=>penalty, :penalized_deviance=>deviance+penalty}
end

# miscellaneous

function get_iter(jm::JAGSModel)
  iter::Int
  iter = ccall( (:get_iter, shlib), Cint, (Ptr{Void},), jm.ji)
end

function get_nchain(jm::JAGSModel)
  return ccall( (:get_nchain, shlib), Cint, (Ptr{Void},), jm.ji)
end

function get_version()
  p = ccall( (:get_version, shlib), Ptr{Cchar}, ())
  name = bytestring(p)
end

end # module
