#include <stdio.h>
#include <string>
#include <sstream>
#include <algorithm>
#include <vector>
#include <deque>
#include <model/BUGSModel.h>
#include <model/Monitor.h>
#include <Module.h>
#include <Console.h>
#include <version.h>
//#include <ltdl.h>

using namespace std;

ostringstream jags_out; //Output stream
ostringstream jags_err; //Error stream
static bool quiet=false; //Suppress information messages

struct jags_info {
  Console *console;
  map<string, SArray> *table;
};

static void printMessages(bool status)
{
    /* Print any messages from JAGS and clear the stream buffer */
    if(!jags_out.str().empty()) {
	if (!quiet) printf("%s\n", jags_out.str().c_str());
	jags_out.str("");
    }
    string msg;
    if (!jags_err.str().empty()) {
	msg = jags_err.str();
	jags_err.str("");
    }
    if (status == true) {
	if (!msg.empty()) {
	    printf("%s\n", msg.c_str());
	}
    }
    else {
	//Something bad happened
	if (!msg.empty()) {
	    fprintf(stderr,"%s\n", msg.c_str());
	}
	else {
	    fprintf(stderr,"Internal error in JAGS library");
	}
    }
}

extern "C" {

void quietMessages(bool arg)
{
  quiet = arg;
}

void clear_console(void *ji)
{
  delete static_cast<jags_info*>(ji)->console;
  delete static_cast<jags_info*>(ji)->table;
  delete static_cast<jags_info*>(ji);
}

void *make_console()
{
  jags_info *ji = new jags_info;
  ji->console = new Console(jags_out, jags_err);
  ji->table = new map<string, SArray>;
  return static_cast<void*>(ji);
}

bool check_model(void *ji, const char *name)
{
  FILE *file = fopen(name, "r");
  if (!file) {
    jags_err << "Failed to open file " << name << "\n";
    return false;
  } else {
    bool status = static_cast<jags_info*>(ji)->console->checkModel(file);	    
    printMessages(status);
    fclose(file);
    return status;
  }
}

void to_sarray(void *ji, const char *name, double *data, const int n)
{
  map<string, SArray> &table = *static_cast<jags_info*>(ji)->table;
  string ename = name;
  SArray sarray(vector<unsigned int>(1, n));
  for (int i=0; i<n; i++) sarray.setValue(data[i],i);
  table.insert(pair<string,SArray>(ename, sarray));  
}

bool compile(void *ji, int nchain, bool gendata)
{
  map<string, SArray> &table = *static_cast<jags_info*>(ji)->table;
  Console &console = *static_cast<jags_info*>(ji)->console;

  bool status = console.compile(table, nchain, gendata);
  printMessages(status);
  return status;
}

int get_variables_size(void *ji)
{
  return static_cast<jags_info*>(ji)->console->variableNames().size();
}
    
const char *get_variable_name(void *ji, const int i)
{
  return static_cast<jags_info*>(ji)->console->variableNames()[i].c_str();
}

bool initialize(void *ji)
{
  bool status = static_cast<jags_info*>(ji)->console->initialize();	    
  printMessages(status);
  return status;
}

bool check_adaptation(void *ji)
{
  bool status;
  static_cast<jags_info*>(ji)->console->checkAdaptation(status);
  return status;
}

bool is_adapting(void *ji)
{
  return static_cast<jags_info*>(ji)->console->isAdapting();
}

void adapt_off(void *ji)
{
  static_cast<jags_info*>(ji)->console->adaptOff();
}

bool update(void *ji, const int niter)
{
  bool status = static_cast<jags_info*>(ji)->console->update(niter);
  if (!status) printMessages(false);
  return status;
}

bool set_monitors(void *ji, char **names, int nnames, int thin, char *type)
{
  bool status;
  int i;
  for (i=0; i<nnames; i++) {
    status = static_cast<jags_info*>(ji)->console->setMonitor(names[i], Range(), thin, type);
    if (!status) return status;
  }
  return true;
}

void clear_monitor(void *ji, char *name, char *type)
{
  static_cast<jags_info*>(ji)->console->clearMonitor(name, Range(), type);
}

int get_monitors_size(void *ji)
{
  return static_cast<jags_info*>(ji)->console->model()->monitors().size();
}
    
const char *get_monitor_name(void *ji, const int i)
{
  list<MonitorControl> const &monitors = static_cast<jags_info*>(ji)->console->model()->monitors();
  list<MonitorControl>::const_iterator it = monitors.begin();
  advance(it, i);
  return it->monitor()->name().c_str();
}
    
int get_monitor_iter(void *ji, const int i)
{
  list<MonitorControl> const &monitors = static_cast<jags_info*>(ji)->console->model()->monitors();
  list<MonitorControl>::const_iterator it = monitors.begin();
  advance(it, i);
  return it->niter();
}

const double *get_monitored_values(void *ji, const int i, const int ichain)
{
  list<MonitorControl> const &monitors = static_cast<jags_info*>(ji)->console->model()->monitors();
  list<MonitorControl>::const_iterator it = monitors.begin();
  advance(it, i);
  return it->monitor()->value(ichain).data();
}

int get_iter(void *ji)
{
  return static_cast<jags_info*>(ji)->console->iter();
}
    
int get_nchain(void *ji)
{
  return static_cast<jags_info*>(ji)->console->nchain();
}

bool load_module(const char *name)
{
  list<Module*>::const_iterator it;
  for (it = Module::modules().begin(); it != Module::modules().end(); ++it) {
    if ((*it)->name() == name) {
      (*it)->load();
      return true;
    }
  }
  return false;
}

int get_modules_size()
{
  return Module::loadedModules().size();
}
    
const char *get_module_name(const int i)
{
  list<Module*>::const_iterator it = Module::loadedModules().begin();
  advance(it, i);
  return (*it)->name().c_str();
}
    
const char *get_version()
{
  return jags_version();
}

}
