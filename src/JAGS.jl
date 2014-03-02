module JAGS

export JAGSLibrary, JAGSModel, set_data, compile, initialize, update, print_variable_names,
       set_monitors, clear_monitors, get_monitors_size, get_monitor_name,
       get_monitor_iter, get_monitored_values, print_monitor_names,
       print_module_names, coef, get_iter, get_nchain

const shlib = joinpath(Pkg.dir("JAGS"),"lib/jags.so")
include("modpath.jl")

type JAGSLibrary
  ji::Ptr{Void}
  function JAGSLibrary()
    if ccall( (:lt_dlinit, :libltdl), Bool, ()); error("unable to initialize libltdl"); end
    ji = ccall( (:make_console, shlib), Ptr{Void}, ())
    ccall( (:lt_dladdsearchdir, "libltdl"), Cint, (Ptr{Uint8},), modpath)
    println("Linked to JAGS ", get_version())
    load_module("basemod")
    load_module("bugs")
    new(ji)
  end
end

type JAGSModel
  ji::Ptr{Void}
  filnam::ASCIIString
  nchain::Int
  status::Symbol
  JAGSModel(jl::JAGSLibrary, filnam::ASCIIString; nchain=1) =
    new(jl.ji, filnam, nchain, :assigned)
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

function adapt(jm::JAGSModel, nadapt::Int)
  status::Bool
  status = false
  if is_adapting(jm)
    jm.status = :adapting
    status = update(jm, nadapt, adapting=true)
    if status
      status = check_adaptation(jm)
    end
  else
    status = true
  end
  return status
end

function initialize(jm::JAGSModel; nadapt=1000)
  status::Bool
  if jm.status!=:model_compiled; return; end
  status = ccall( (:initialize, shlib), Bool, (Ptr{Void},), jm.ji)
  if nadapt>0; status = adapt(jm, nadapt); end
  if status; jm.status=:model_initialized; end
  return status
end

function update(jm::JAGSModel, niter::Int; adapting=false)
  if adapting
    if jm.status!=:model_compiled; return; end
  else
    if jm.status!=:model_initialized; return; end
  end
  if adapting; mode="Adapting"; else mode="Updating"; end
  status = true
  i = 0
  istep = iround(niter/100)
  idone = 0
  iiter = istep
  while idone<niter
    if idone+istep>niter; iiter=niter-idone; end
    print('\r',mode,": ",i,'%')
    status = ccall( (:update, shlib), Bool, (Ptr{Void},Cint), jm.ji, iiter)
    if !status; break; end
    idone += iiter
    i += 1
  end
  println('\r',mode,": ",i,"% done")
  return idone
end

# data

function set_data(jm::JAGSModel, name::ASCIIString, value::Int)
  ccall( (:to_sarray, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Cint), jm.ji, name, &value, 1)
end

function set_data(jm::JAGSModel, name::ASCIIString, value::Real)
  ccall( (:to_sarray, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Cint), jm.ji, name, &value, 1)
end

function set_data(jm::JAGSModel, name::ASCIIString, values::Array{Float64})
  ccall( (:to_sarray, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Cdouble},Cint), jm.ji, name, values, length(values))
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

# monitors (default range and types "trace")

function set_monitors(jm::JAGSModel, names::Array{ASCIIString}; thin=1)
  status::Bool
  if jm.status!=:model_initialized; return false; end
  status = ccall( (:set_monitors, shlib), Bool, (Ptr{Void},Ptr{Ptr{Uint8}},Cint,Cint,Ptr{Uint8}), jm.ji, names, length(names), thin, "trace")
  if !status; warn("monitors not set"); end
end

function clear_monitors(jm::JAGSModel)
  for i=1:get_monitors_size(jm)
    clear_monitor(jm, get_monitor_name(jm, i))
  end
end

function clear_monitor(jm::JAGSModel, name::ASCIIString)
  ccall( (:clear_monitor, shlib), Void, (Ptr{Void},Ptr{Uint8},Ptr{Uint8}), jm.ji, name, "trace")
end

function get_monitor_name(jm::JAGSModel, i::Int)
  p = ccall( (:get_monitor_name, shlib), Ptr{Cchar}, (Ptr{Void},Cint), jm.ji, i-1)
  name = bytestring(p)
end

function get_monitor_iter(jm::JAGSModel, i::Int)
  iter::Int
  iter = ccall( (:get_monitor_iter, shlib), Cint, (Ptr{Void},Cint), jm.ji, i-1)
end

function get_monitors_size(jm::JAGSModel)
  if jm.status!=:model_initialized; return 0; end
  return ccall( (:get_monitors_size, shlib), Cint, (Ptr{Void},), jm.ji)
end

function get_monitored_values(jm::JAGSModel, i::Int, ichain::Int)
  p::Ptr{Cdouble}
  iter::Int
  iter = get_monitor_iter(jm, i)
  p = ccall( (:get_monitored_values, shlib), Ptr{Cdouble}, (Ptr{Void},Cint,Cint), jm.ji, i-1, ichain-1)
  return pointer_to_array(p, iter, false)
end

function print_monitor_names(jm::JAGSModel)
  print("Monitor names:")
  for i=1:get_monitors_size(jm)
    print(' ',get_monitor_name(jm,i))
  end
  println('\n')
end

function coef(jm::JAGSModel, i::Int, chain::Int)
  v = get_monitored_values(jm,i,chain)
  [mean(v) std(v) quantile(v,0.025) quantile(v,0.5) quantile(v,0.975)]
end

function coef(jm::JAGSModel; chain=1)
  { get_monitor_name(jm,i) => coef(jm,i,chain) for i=1:get_monitors_size(jm) }
end

# adaptation

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
