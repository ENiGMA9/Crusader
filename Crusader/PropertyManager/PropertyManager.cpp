#include "PropertyManager.h"

#ifndef _FSTREAM_
#include <fstream>
#endif

#ifndef PROPERTY_MANAGER_CPP
#define PROPERTY_MANAGER_CPP
Property* PropertyManager::start = new Property();

Property* PropertyManager::findPropertyByName(const char *property_name)
{
	Property *iterator = start;
	while (iterator->getNextProperty())
	{
		if (strcmp(iterator->getPropertyName(), property_name)==0)
		{
			return iterator;
		}
		iterator = iterator->getNextProperty();
	}
	if (strcmp(iterator->getPropertyName(), property_name)==0)
	{
		return iterator;
	}
	//throw "PROPERTY NOT FOUND";
	return false;
}

int PropertyManager::getPropertyValueWithName(const char *property_name){
	Property *target_property;
	try{
		target_property = findPropertyByName(property_name);
	}
	catch (char *error)
	{
		throw (error);
		return 0;
	}
	return target_property->getPropertyValue();
};

void PropertyManager::setPropertyValueFor(const char *property_name, int value_to_set){
	Property *target_property;
	try{
		target_property = findPropertyByName(property_name);
	}
	catch (char *error)
	{
		throw (error);
	}
	target_property->setPropertyValue(value_to_set);
}

Property *PropertyManager::getLastProperty(){
	Property *iterator = start;
	if (!start)
	{
		//
	}
	else
	{
		while (iterator->getNextProperty())
		{
			iterator = iterator->getNextProperty();
		}
	}
	return iterator;
}

void PropertyManager::registerProperty(const char *property_name, int &variable_adress){
	Property *last_property = PropertyManager::getLastProperty();
	last_property->pushProperty(new Property(property_name, &variable_adress));
}


void PropertyManager::loadCfg(char* cfgname) {
	std::ifstream input_file(cfgname);
	if (input_file){
		std::string input_buffer;
		std::string variable_name;
		std::string variable_value;
		while (std::getline(input_file, input_buffer))
		{
			if (input_buffer.find("#") == std::string::npos) {
				variable_name = input_buffer.substr(0, input_buffer.find("="));
				variable_value = input_buffer.substr(input_buffer.find("=") + 1, input_buffer.length());
				const char* aux_char = variable_name.c_str();
				Property *temp_property = PropertyManager::findPropertyByName(aux_char);
				if (temp_property)
				{
					temp_property->setPropertyValue(atoi(variable_value.c_str()));
				}
			}
		}

		input_file.close();
	}
	else
	{
		throw "cfg unusable";
	}
}


#endif