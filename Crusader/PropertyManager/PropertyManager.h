#ifndef PROPERTIES_H
#include "Properties.h"
#endif

#ifndef _STRING_
#include <string>
#endif


#ifndef PROPERTY_MANAGER_H
#define PROPERTY_MANAGER_H
class PropertyManager{
private:
	static Property *start;
	static Property *findPropertyByName(const char *property_name);
	static int getPropertyValueWithName(const char *property_name);
	static void setPropertyValueFor(const char *property_name, int value_to_set);
	static Property *getLastProperty();
public:
	static void registerProperty(const char *property_name, int &variable_adress);
	static void loadCfg(char* cfgname);
	PropertyManager();
	~PropertyManager();
};
#endif