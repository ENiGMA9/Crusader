#ifndef SAVE_MANAGER_H
#define SAVE_MANAGER_H


class SaveManager{
private:
	static struct Save{
		int savedTarget;
		unsigned int *savedWord;
	}
	session;
	static int valid;
public:
	//Pass the size of the alphabet to check if the saved word has letters out of current alphabet's range.
	static void load(char* filename, int alphabetSize = 0);

	static void save(char* filename);
	static int isValid();
	static void cleanup();
};




#endif