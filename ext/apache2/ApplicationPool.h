#ifndef _PASSENGER_APPLICATION_POOL_H_
#define _PASSENGER_APPLICATION_POOL_H_

#include <boost/shared_ptr.hpp>
#include <boost/thread/mutex.hpp>

#include <string>
#include <map>

#include "SpawnManager.h"

namespace Passenger {

using namespace std;
using namespace boost;

class ApplicationPool {
public:
	virtual ~ApplicationPool() {};
	
	virtual ApplicationPtr get(const string &appRoot, const string &user = "", const string &group = "") = 0;
};

// TODO: document this
class StandardApplicationPool: public ApplicationPool {
private:
	typedef map<string, ApplicationPtr> ApplicationMap;

	SpawnManager spawnManager;
	ApplicationMap apps;
	mutex lock;
	bool threadSafe;
	
	string normalizePath(const string &path) {
		// TODO
		return path;
	}
	
public:
	StandardApplicationPool(const string &spawnManagerCommand,
	             const string &logFile = "",
	             const string &environment = "production",
	             const string &rubyCommand = "ruby")
	: spawnManager(spawnManagerCommand, logFile, environment, rubyCommand) {
		threadSafe = false;
	}
	
	void setThreadSafe() {
		threadSafe = true;
	}
	
	// TODO: improve algorithm
	virtual ApplicationPtr get(const string &appRoot, const string &user = "", const string &group = "") {
		string normalizedAppRoot(normalizePath(appRoot));
		ApplicationPtr app;
		mutex::scoped_lock l(lock, threadSafe);
		
		ApplicationMap::iterator it(apps.find(appRoot));
		if (it == apps.end()) {
			app = spawnManager.spawn(appRoot, user, group);
			apps[appRoot] = app;
		} else {
			app = it->second;
		}
		return app;
	}
};

typedef shared_ptr<ApplicationPool> ApplicationPoolPtr;

}; // namespace Passenger

#endif /* _PASSENGER_APPLICATION_POOL_H_ */
