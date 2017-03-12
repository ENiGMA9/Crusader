#ifndef PROPERTIES_H
#include "Properties.h"
#endif

#ifndef _INC_STRING
#include <string.h>
#endif

#ifndef PROPERTIES_CPP
#define PROPERTIES_CPP

void Property::setPropertyValue(int property_value_to_set){
	*property_adress = property_value_to_set;
}

int Property::getPropertyValue()
{
	return *property_adress;
}

char* Property::getPropertyName()
{
	return property_name;
}

void Property::pushProperty(Property *property_to_push)
{
	next_property = property_to_push;
}

Property *Property::getNextProperty(){
	if (this->next_property)
	{
		return this->next_property;
	}
	//throw "NO NEXT ELEMENT";
	return false;
}

Property::Property(const char *property_set_name,int *property_address_link)
{

	strcpy_s(property_name,64,property_set_name);
	next_property = nullptr;
	property_adress = property_address_link;

}

Property::Property(){
	property_adress = nullptr;
	next_property = nullptr;
	strcpy_s(property_name,64,"START_PROPERTY");
}

Property::~Property(){
	delete(next_property);
}

#endif