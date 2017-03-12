#ifndef SAVE_MANAGER_H
#define SAVE_MANAGER_H


static class SaveManager{
private:
	struct Save{
		int savedTarget;
		unsigned int *savedWord;
	}
	session;
	int valid;
public:
	//Pass the size of the alphabet to check if the saved word has letters out of current alphabet's range.
	 void load(const char* filename, int alphabetSize = 0);

	void save(const char* filename);
	int isValid();
	void cleanup();
};




#endif