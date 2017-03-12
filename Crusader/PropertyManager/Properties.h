#ifndef PROPERTIES_H
#define PROPERTIES_H
class Property{
private:
	Property *next_property;
	char property_name[64];
	int *property_adress;
public:
	void setPropertyValue(int property_value_to_set);
	int getPropertyValue();
	char* getPropertyName();
	Property *getNextProperty();
	void pushProperty(Property *property_to_push);
	Property(const char *property_set_name, int *property_address_link);
	Property();
	~Property();
};
#endif